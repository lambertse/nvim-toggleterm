local M = {}

local state = {
  buf = nil,  -- terminal buffer handle (number)
  win = nil,  -- floating window handle (number)
  opts = nil,
}

-- =========
-- Utilities
-- =========
local function is_valid_win(win)
  return type(win) == "number" and win > 0 and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return type(buf) == "number" and buf > 0 and vim.api.nvim_buf_is_valid(buf)
end

local function compute_size()
  local width = math.floor(vim.o.columns * state.opts.width)
  local height = math.floor(vim.o.lines * state.opts.height)
  width = math.max(10, math.min(width, vim.o.columns - 2))
  height = math.max(5, math.min(height, vim.o.lines - 2))
  return width, height
end

local function center_coords(width, height)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  return col, row
end

local function ensure_terminal_buffer()
  -- Reuse existing buffer if valid and terminal
  if is_valid_buf(state.buf) and vim.bo[state.buf].buftype == "terminal" then
    return state.buf
  end

  local buf = vim.api.nvim_create_buf(false, true) -- scratch, listed=false
  -- NOTE: `termopen` attaches a job; `vim.cmd.terminal()` would create a window.
  vim.api.nvim_buf_call(buf, function()
    vim.fn.termopen(vim.o.shell or vim.env.SHELL or "sh")
  end)

  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "terminal"

  state.buf = buf
  return buf
end

local function create_or_open_window()
  local buf = ensure_terminal_buffer()

  local width, height = compute_size()
  local col, row = center_coords(width, height)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row - 2, -- -2 for terminator navbar
    style = "minimal",
    border = state.opts.border,
  }

  -- Neovim 0.9+: optional title
  if state.opts.title and vim.fn.has("nvim-0.9") == 1 then
    win_config.title = state.opts.title
    win_config.title_pos = "center"
  end

  local win = nil
  if is_valid_win(state.win) then
    -- Reconfigure existing window (resize/recenter)
    vim.api.nvim_win_set_config(state.win, win_config)
    win = state.win
  else
    -- Create a new floating window
    win = vim.api.nvim_open_win(buf, true, win_config)
    state.win = win
  end

  -- Enter insert mode if requested
  if state.opts.start_in_insert then
    vim.cmd.startinsert()
  end

  return { buf = buf, win = win }
end

-- =========
-- Public API
-- =========

function M.open()
  -- If window exists, just focus it
  if is_valid_win(state.win) then
    vim.api.nvim_set_current_win(state.win)
    if state.opts.start_in_insert then
      vim.cmd.startinsert()
    end
    return
  end
  create_or_open_window()
end

function M.close()
  if is_valid_win(state.win) then
    -- Hide window without wiping buffer
    pcall(vim.api.nvim_win_hide, state.win)
    state.win = nil
  end
end

function M.toggle()
  if is_valid_win(state.win) then
    M.close()
  else
    M.open()
  end
end

function M.resize()
  if not is_valid_win(state.win) then
    return
  end
  local width, height = compute_size()
  local col, row = center_coords(width, height)
  local cfg = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = state.opts.border,
  }
  if state.opts.title and vim.fn.has("nvim-0.9") == 1 then
    cfg.title = state.opts.title
    cfg.title_pos = "center"
  end
  vim.api.nvim_win_set_config(state.win, cfg)
end

function M.is_open()
  return is_valid_win(state.win)
end

function M.setup(opts)
  local config = require("nvim-toggleterm.config")
  state.opts = config.merge(opts) 

  if state.opts.create_user_command then
    vim.api.nvim_create_user_command("FloatingTerminalOpen", function() M.open() end, {})
    vim.api.nvim_create_user_command("FloatingTerminalClose", function() M.close() end, {})
    vim.api.nvim_create_user_command("FloatingTerminalToggle", function() M.toggle() end, {})
    vim.api.nvim_create_user_command("FloatingTerminalResize", function() M.resize() end, {})
  end

  if state.opts.create_keymap and state.opts.keymap and state.opts.keymap ~= "" then
    vim.keymap.set("n", state.opts.keymap, M.toggle, { desc = "Toggle floating terminal" })
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("FloatingTerminalAutoResize", { clear = true }),
    callback = function()
      if M.is_open() then
        -- Defer slightly to allow UI to settle
        vim.defer_fn(function()
          if M.is_open() then
            M.resize()
          end
        end, 10)
      end
    end,
  })

  if state.opts.close_on_job_exit then
    vim.api.nvim_create_autocmd("TermClose", {
      group = vim.api.nvim_create_augroup("FloatingTerminalCleanup", { clear = true }),
      callback = function(args)
        local buf = args.buf
        if is_valid_buf(buf) and buf == state.buf then
          -- Only close the window if it's showing this buffer
          if is_valid_win(state.win) and vim.api.nvim_win_get_buf(state.win) == buf then
            pcall(vim.api.nvim_win_hide, state.win)
            state.win = nil
          end
        end
      end,
    })
  end
end

return M
