local M = {}

M.defaults = {
  width = 0.8,       -- fraction of columns
  height = 0.8,      -- fraction of lines
  border = "double", -- "single", "double", "rounded", "solid", "shadow", or border table
  start_in_insert = true,
  create_user_command = true,
  create_keymap = false,   -- set to true to create <leader>tt
  keymap = "<leader>tt",   -- toggle key
  close_on_job_exit = true,
  title = "Terminal",      -- optional window title (Neovim 0.9+)
}

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M

