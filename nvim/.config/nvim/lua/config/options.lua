-- Leader keys
vim.g.mapleader = "\\"
vim.g.maplocalleader = " "

-- Wayland clipboard support
vim.g.clipboard = {
  name = 'WlClipboard',
  copy = {
    ['+'] = 'wl-copy',
    ['*'] = 'wl-copy',
  },
  paste = {
    ['+'] = 'wl-paste --no-newline',
    ['*'] = 'wl-paste --no-newline',
  },
  cache_enabled = 0,
}
vim.opt.clipboard = "unnamedplus"

-- Tab settings
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
