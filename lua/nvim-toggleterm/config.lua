local M = {}

M.defaults = {
  width = 0.8,            -- fraction of columns
  height = 0.8,           -- fraction of lines
  border = "double",      -- "single", "double", "rounded", "solid", "shadow", or border table
  start_in_insert = true,
  create_user_command = true,
  create_keymap = false,  -- set to true to create the global toggle keymap
  keymap = "<leader>tt",  -- global toggle key (normal mode)
  close_on_job_exit = true,
  title = "Terminal",     -- floating window border title (Neovim 0.9+); nil to disable
  session_name_prefix = "Terminal", -- default name prefix for new sessions

  -- Buffer-local keymaps active inside the terminal window (normal + terminal mode).
  -- Set any to "" or nil to disable.
  keymap_new          = "<A-n>", -- create a new terminal session
  keymap_close_session= "<A-x>", -- close the active session
  keymap_next         = "<A-l>", -- switch to next session
  keymap_prev         = "<A-h>", -- switch to previous session
  keymap_rename       = "<A-r>", -- rename the active session
}

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
