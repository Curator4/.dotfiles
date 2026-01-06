# Migration Plan: LazyVim to Ultra-Minimal Neovim Config

## Overview
Migrate from LazyVim (full-featured distribution) to an ultra-minimal Neovim configuration with only the essential clipboard sync for Wayland. This provides maximum control and understanding of the configuration.

## User Requirements
- **Minimalism**: Ultra minimal - no plugin manager, no plugins
- **Must keep**: Wayland clipboard sync (`clipboard = "unnamedplus"`)
- **Goal**: Learn Neovim configuration by managing it directly

## Implementation Steps

### 1. Backup Current LazyVim Configuration
**Action**: Rename the existing config directory to preserve it for reference
- **From**: `/home/curator/.dotfiles/nvim/.config/nvim/`
- **To**: `/home/curator/.dotfiles/nvim/.config/nvim.lazyvim-backup/`
- **Why**: Allows referencing old settings and easy recovery if needed

### 2. Create Minimal Directory Structure
**Create**: `/home/curator/.dotfiles/nvim/.config/nvim/`
- `init.lua` - Single configuration file (~30-50 lines)
- `README.md` - Migration notes and extension guide (optional)

### 3. Create Minimal init.lua
**File**: `/home/curator/.dotfiles/nvim/.config/nvim/init.lua`

**Contents** (~30-50 lines):

#### Essential Options (Required)
```lua
-- Wayland clipboard sync (ESSENTIAL)
vim.opt.clipboard = "unnamedplus"

-- User preferences from old config
vim.opt.relativenumber = false  -- no relative line numbers
vim.opt.wrap = true             -- enable line wrapping
```

#### Sensible Defaults (Recommended but optional)
```lua
vim.opt.number = true           -- show line numbers
vim.opt.tabstop = 2             -- 2 spaces per tab
vim.opt.shiftwidth = 2          -- 2 spaces for indents
vim.opt.expandtab = true        -- use spaces instead of tabs
vim.opt.ignorecase = true       -- case-insensitive search
vim.opt.smartcase = true        -- smart case matching
vim.opt.splitright = true       -- vertical splits go right
vim.opt.splitbelow = true       -- horizontal splits go below
```

#### Basic Keymaps (Optional)
```lua
-- Set leader key to Space
vim.g.mapleader = " "

-- Window navigation (optional)
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
```

### 4. Create README.md (Optional)
**File**: `/home/curator/.dotfiles/nvim/.config/nvim/README.md`

Document:
- What was removed and why
- Where to find LazyVim backup
- How to add plugins manually later (git submodules, vim-plug, etc.)
- Links to Neovim documentation

### 5. Test Configuration
Verify:
- Neovim starts without errors
- Clipboard sync works (copy/paste between nvim and system)
- Basic editing, navigation, and file operations work
- Check with `:set clipboard?` to confirm setting is active

### 6. Git Integration
Since dotfiles are managed with GNU Stow:
- Stage the new minimal config
- Commit with message: "migrate: LazyVim to ultra-minimal Neovim config"
- Old LazyVim backup remains accessible for reference

## Critical Files

**Files to Create**:
- `/home/curator/.dotfiles/nvim/.config/nvim/init.lua` (new minimal config)
- `/home/curator/.dotfiles/nvim/.config/nvim/README.md` (optional documentation)

**Files to Preserve**:
- `/home/curator/.dotfiles/nvim/.config/nvim.lazyvim-backup/` (renamed from original)
  - Contains all plugin configs, LSP settings, themes for future reference

## Future Extension Path

Once comfortable with ultra-minimal setup, can extend with:
1. Manual plugin installation via git submodules in `~/.local/share/nvim/site/pack/`
2. Add a minimal plugin manager (vim-plug, packer.nvim) if needed
3. Gradually add back features from LazyVim backup as understood
4. Structure config into modules: `lua/config/options.lua`, `lua/config/keymaps.lua`, etc.

## Trade-offs
**Lost**: All plugins (LSP, treesitter, themes, formatters, etc.)
**Gained**: Complete understanding and control of configuration
**Recovery**: Full LazyVim backup available at `nvim.lazyvim-backup/`
