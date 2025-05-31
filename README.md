# nvim-dotnet-utils

A Neovim Lua plugin to build and watch .NET projects inside toggled terminal
splits.

## Features

- Auto detects `.csproj` files in your project
- Opens terminal splits: horizontal bottom, then vertical splits side by side
- Toggles running terminal instead of opening new terminals
- Cleans up terminal buffers on exit
- Keymaps for build, watch, and reset last selected project
- Fixed terminal window sizes for stable UI

## Requirements

- Neovim 0.7+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for scanning files)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "engmhajj/nvim-dotnet-utils",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("dotnet-utils").setup()
  end,
}
```
