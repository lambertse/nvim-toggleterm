# nvim-toggleterm

A tiny, dependency‑free Neovim plugin to open/toggle a floating terminal centered on your screen.
It reuses a single terminal buffer, remembers your preferences, and resizes automatically on UI changes.

> ✅ Works with Neovim 0.8+ (optional window title on 0.9+) \
> 🧩 Zero deps, pure Lua \
> 🪟 Floating window with configurable border, size, and title \
> ⌨️ Optional user command + keymap generation \
> 🧠 Reuses a single terminal buffer (fast & tidy) \
> 🔄 Auto-resizes on VimResized \
> 🧼 Auto-close when the shell job exits (configurable) \

## Screenshots

![Screenshot](asset/nvim-toggleterm.png)

## Requirements
- **Neovim**: 0.8 or newer
  - Optional: **0.9+** to display a floating window title

## Installation
### lazy.nvim
```
{
  "lambertse/nvim-toggleterm",
  config = function()
    require("nvim-toggleterm").setup({
      -- see full options below
      width = 0.8,
      height = 0.8,
      border = "rounded",
      start_in_insert = true,
      create_user_command = true,
      create_keymap = true,
      keymap = "<leader>tt",
      close_on_job_exit = true,
      title = "Terminal",
    })
  end,
}
```

### packer.nvim
```
use({
  "lambertse/nvim-toggleterm",
  config = function()
    require("nvim-toggleterm").setup()
  end,
})
```
### vim-plug
```
Plug 'lambertse/nvim-toggleterm'
```
Then in your init.Lua
```
require("nvim-toggleterm").setup()
```

## Quick Start
Quick Start
Once installed, you can:

- Toggle the floating terminal (with user commands):
```
:FloatingTerminalToggleShow
```

- Open it:
```
:FloatingTerminalOpenShow
```

- Close it:
```
:FloatingTerminalCloseShow 
```

- Resize it to your config (useful after you change vim.o.columns/lines dynamically):
```
:FloatingTerminalResizeShow 
```

If you enable the default keymap in config (create_keymap = true), you’ll also get:

- <leader>tt → Toggle floating terminal

## Configuration
```
M.defaults = {
  width = 0.8,            -- fraction of columns (0 < x <= 1)
  height = 0.8,           -- fraction of lines    (0 < x <= 1)
  border = "rounded",     -- "single" | "double" | "rounded" | "solid" | "shadow" | table
  start_in_insert = true, -- enter insert mode after opening
  create_user_command = true, -- create :FloatingTerminal* commands
  create_keymap = false,      -- set true to create <leader>tt
  keymap = "<leader>tt",      -- toggle key (normal mode)
  close_on_job_exit = true,   -- close window when terminal job exits
  title = "Terminal",         -- (NeoVim 0.9+) floating window title (nil to disable)
}
```
You can override any of these in setup():
```
require("nvim-toggleterm").setup({
  width = 0.7,
  height = 0.6,
  border = "single",
  title = "Shell",
})
```

## Commands
Created when create_user_command = true:

- :FloatingTerminalOpen – Open (or focus) the terminal window.
- :FloatingTerminalClose – Hide the floating window (buffer persists).
- :FloatingTerminalToggle – Toggle open/close.
- :FloatingTerminalResize – Recompute geometry and apply.

## Contributing
PRs and issues are welcome!
Please keep changes small and focused, and add docs/notes for new behaviors.

- Fork and create a feature branch.
- Add/adjust unit/integration tests if applicable.
- Update README for any new options.
- Open a PR with a clear description.

## License
MIT — do whatever you want, just keep the license and attribution.

