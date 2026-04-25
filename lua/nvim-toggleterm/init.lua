local M = {}

local state = {
  sessions   = {},  -- array of { id, buf, name }
  active_idx = 0,   -- 1-based index into sessions; 0 means no sessions
  win        = nil, -- floating window handle
  opts       = nil,
  _next_id   = 1,
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
  local width  = math.floor(vim.o.columns * state.opts.width)
  local height = math.floor(vim.o.lines   * state.opts.height)
  width  = math.max(10, math.min(width,  vim.o.columns - 2))
  height = math.max(5,  math.min(height, vim.o.lines   - 2))
  return width, height
end

local function center_coords(width, height)
  local col = math.floor((vim.o.columns - width)  / 2)
  local row = math.floor((vim.o.lines   - height) / 2)
  return col, row
end

local function escape_winbar(s)
  return tostring(s):gsub("%%", "%%%%")
end

-- =========
-- Winbar
-- =========
local function update_winbar()
  if not is_valid_win(state.win) then return end
  local parts = {}
  for i, session in ipairs(state.sessions) do
    local label = escape_winbar(i .. ":" .. session.name)
    if i == state.active_idx then
      parts[#parts + 1] = "%#TabLineSel# " .. label .. " "
    else
      parts[#parts + 1] = "%#TabLine# " .. label .. " "
    end
  end
  vim.wo[state.win].winbar = table.concat(parts) .. "%#TabLineFill#%="
end

-- =========
-- Sessions
-- =========
local function map_if_set(modes, lhs, fn, buf)
  if not (lhs and lhs ~= "") then return end
  for _, mode in ipairs(modes) do
    vim.keymap.set(mode, lhs, fn, { buffer = buf, silent = true })
  end
end

local function set_buf_keymaps(buf)
  local o = state.opts
  map_if_set({ "t", "n" }, o.keymap_new,           function() M.new_terminal() end,   buf)
  map_if_set({ "t", "n" }, o.keymap_close_session,  function() M.close_terminal() end, buf)
  map_if_set({ "t", "n" }, o.keymap_next,           function() M.next_terminal() end,  buf)
  map_if_set({ "t", "n" }, o.keymap_prev,           function() M.prev_terminal() end,  buf)
  map_if_set({ "t", "n" }, o.keymap_rename,         function() M.rename_terminal() end, buf)
end

local function create_session(name)
  local id = state._next_id
  state._next_id = state._next_id + 1
  name = name or (state.opts.session_name_prefix .. " " .. id)

  local buf = vim.api.nvim_create_buf(false, true)
  -- NOTE: `termopen` attaches a job without creating a window.
  vim.api.nvim_buf_call(buf, function()
    vim.fn.termopen(vim.o.shell or vim.env.SHELL or "sh")
  end)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype  = "terminal"

  table.insert(state.sessions, { id = id, buf = buf, name = name })
  set_buf_keymaps(buf)
  return #state.sessions
end

-- =========
-- Window management
-- =========
local function make_win_config(width, height, col, row)
  local cfg = {
    relative = "editor",
    width    = width,
    height   = height,
    col      = col,
    row      = row - 2, -- -2 for terminator navbar
    style    = "minimal",
    border   = state.opts.border,
  }
  if state.opts.title and vim.fn.has("nvim-0.9") == 1 then
    cfg.title     = state.opts.title
    cfg.title_pos = "center"
  end
  return cfg
end

local function load_session_into_win(idx)
  if not is_valid_win(state.win) then return end
  local session = state.sessions[idx]
  if not (session and is_valid_buf(session.buf)) then return end
  state.active_idx = idx
  vim.api.nvim_win_set_buf(state.win, session.buf)
  update_winbar()
  if state.opts.start_in_insert then
    pcall(vim.cmd.startinsert)
  end
end

-- =========
-- Public API
-- =========

function M.open()
  if #state.sessions == 0 then
    state.active_idx = create_session()
  end

  if is_valid_win(state.win) then
    vim.api.nvim_set_current_win(state.win)
    if state.opts.start_in_insert then vim.cmd.startinsert() end
    return
  end

  local width, height = compute_size()
  local col, row      = center_coords(width, height)
  local buf           = state.sessions[state.active_idx].buf
  state.win = vim.api.nvim_open_win(buf, true, make_win_config(width, height, col, row))
  update_winbar()
  if state.opts.start_in_insert then vim.cmd.startinsert() end
end

function M.close()
  if is_valid_win(state.win) then
    pcall(vim.api.nvim_win_hide, state.win)
    state.win = nil
  end
end

function M.toggle()
  if is_valid_win(state.win) then M.close() else M.open() end
end

function M.resize()
  if not is_valid_win(state.win) then return end
  local width, height = compute_size()
  local col, row      = center_coords(width, height)
  vim.api.nvim_win_set_config(state.win, make_win_config(width, height, col, row))
end

function M.is_open()
  return is_valid_win(state.win)
end

-- Create a new terminal session and immediately switch to it.
function M.new_terminal(name)
  local idx = create_session(name)
  if is_valid_win(state.win) then
    load_session_into_win(idx)
  else
    state.active_idx = idx
    M.open()
  end
end

-- Close the active session. Switches to an adjacent session, or closes the
-- window when the last session is removed.
function M.close_terminal()
  if #state.sessions == 0 then return end
  local idx     = state.active_idx
  local session = table.remove(state.sessions, idx)

  local buf_to_wipe = session.buf
  vim.schedule(function()
    if is_valid_buf(buf_to_wipe) then
      pcall(vim.api.nvim_buf_delete, buf_to_wipe, { force = true })
    end
  end)

  if #state.sessions == 0 then
    M.close()
    state.active_idx = 0
  else
    local new_idx = math.min(idx, #state.sessions)
    if is_valid_win(state.win) then
      load_session_into_win(new_idx)
    else
      state.active_idx = new_idx
    end
  end
end

function M.next_terminal()
  if #state.sessions <= 1 then return end
  load_session_into_win((state.active_idx % #state.sessions) + 1)
end

function M.prev_terminal()
  if #state.sessions <= 1 then return end
  load_session_into_win(((state.active_idx - 2) % #state.sessions) + 1)
end

-- Switch to a specific session by 1-based index.
function M.switch_terminal(idx)
  idx = tonumber(idx)
  if not idx or idx < 1 or idx > #state.sessions then return end
  if is_valid_win(state.win) then
    load_session_into_win(idx)
  else
    state.active_idx = idx
    M.open()
  end
end

-- Rename the active session. Prompts via vim.ui.input when name is omitted.
function M.rename_terminal(name)
  if #state.sessions == 0 then return end
  local session = state.sessions[state.active_idx]
  if name then
    session.name = name
    update_winbar()
  else
    vim.ui.input({ prompt = "Rename terminal: ", default = session.name }, function(input)
      if input and input ~= "" then
        session.name = input
        update_winbar()
      end
    end)
  end
end

-- Returns a list of { id, name, active } for all sessions.
function M.get_sessions()
  local result = {}
  for i, s in ipairs(state.sessions) do
    result[i] = { id = s.id, name = s.name, active = (i == state.active_idx) }
  end
  return result
end

function M.setup(opts)
  local config = require("nvim-toggleterm.config")
  state.opts = config.merge(opts)

  if state.opts.create_user_command then
    vim.api.nvim_create_user_command("FloatingTerminalOpen",         function()    M.open()                                            end, {})
    vim.api.nvim_create_user_command("FloatingTerminalClose",        function()    M.close()                                           end, {})
    vim.api.nvim_create_user_command("FloatingTerminalToggle",       function()    M.toggle()                                          end, {})
    vim.api.nvim_create_user_command("FloatingTerminalResize",       function()    M.resize()                                          end, {})
    vim.api.nvim_create_user_command("FloatingTerminalNew",          function(a)   M.new_terminal(a.args ~= "" and a.args or nil)      end, { nargs = "?" })
    vim.api.nvim_create_user_command("FloatingTerminalCloseSession", function()    M.close_terminal()                                  end, {})
    vim.api.nvim_create_user_command("FloatingTerminalNext",         function()    M.next_terminal()                                   end, {})
    vim.api.nvim_create_user_command("FloatingTerminalPrev",         function()    M.prev_terminal()                                   end, {})
    vim.api.nvim_create_user_command("FloatingTerminalRename",       function(a)   M.rename_terminal(a.args ~= "" and a.args or nil)   end, { nargs = "?" })
    vim.api.nvim_create_user_command("FloatingTerminalSwitch",       function(a)   M.switch_terminal(a.args)                          end, { nargs = 1 })
  end

  if state.opts.create_keymap and state.opts.keymap and state.opts.keymap ~= "" then
    vim.keymap.set("n", state.opts.keymap, M.toggle, { desc = "Toggle floating terminal" })
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group    = vim.api.nvim_create_augroup("FloatingTerminalAutoResize", { clear = true }),
    callback = function()
      if M.is_open() then
        vim.defer_fn(function()
          if M.is_open() then M.resize() end
        end, 10)
      end
    end,
  })

  if state.opts.close_on_job_exit then
    vim.api.nvim_create_autocmd("TermClose", {
      group    = vim.api.nvim_create_augroup("FloatingTerminalCleanup", { clear = true }),
      callback = function(args)
        local closed_buf = args.buf
        local found_idx  = nil
        for i, session in ipairs(state.sessions) do
          if session.buf == closed_buf then
            found_idx = i
            break
          end
        end
        if not found_idx then return end

        -- Record old active before mutating the list.
        local old_active = state.active_idx
        table.remove(state.sessions, found_idx)

        vim.schedule(function()
          if #state.sessions == 0 then
            if is_valid_win(state.win) then
              pcall(vim.api.nvim_win_hide, state.win)
              state.win = nil
            end
            state.active_idx = 0
          elseif found_idx == old_active then
            -- The displayed session exited: switch to nearest remaining session.
            local new_idx = math.min(old_active, #state.sessions)
            if is_valid_win(state.win) then
              load_session_into_win(new_idx)
            else
              state.active_idx = new_idx
            end
          elseif found_idx < old_active then
            -- A session before the active one was removed: shift index down.
            state.active_idx = old_active - 1
            update_winbar()
          else
            -- A session after the active one was removed: just redraw.
            update_winbar()
          end
        end)
      end,
    })
  end
end

return M
