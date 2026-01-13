#!/usr/bin/env -S nvim -l

-- Usage: nvim -l extract-nvim-colors.lua <colorscheme-name>
-- Outputs JSON palette to stdout

local colorscheme = arg[1]
if not colorscheme then
	print("Usage: nvim -l extract-nvim-colors.lua <colorscheme-name>")
	os.exit(1)
end

-- Minimal init
vim.opt.termguicolors = true

-- Add lazy.nvim to runtimepath so plugins are available
local lazypath = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(lazypath .. "/lazy.nvim")

-- Add all plugin directories to runtimepath
for _, plugin_dir in ipairs(vim.fn.glob(lazypath .. "/*", false, true)) do
	vim.opt.rtp:append(plugin_dir)
end

-- Try to load the colorscheme
local ok = pcall(vim.cmd.colorscheme, colorscheme)
if not ok then
	print("Error: Could not load colorscheme '" .. colorscheme .. "'")
	os.exit(1)
end

-- Helper to convert highlight to hex
local function hl_to_hex(hl_group)
	local hl = vim.api.nvim_get_hl(0, { name = hl_group, link = false })
	return hl
end

-- Extract colors
local normal = hl_to_hex("Normal")
local cursor = hl_to_hex("Cursor")
local visual = hl_to_hex("Visual")

-- Terminal colors
local terminal_colors = {}
for i = 0, 15 do
	local var = "terminal_color_" .. i
	if vim.g[var] then
		terminal_colors[tostring(i)] = vim.g[var]
	end
end

-- Build palette JSON
local palette = {
	background = string.format("#%06x", normal.bg or 0x000000),
	foreground = string.format("#%06x", normal.fg or 0xffffff),
	cursor = string.format("#%06x", cursor.bg or normal.fg or 0xffffff),
	cursor_text = string.format("#%06x", cursor.fg or normal.bg or 0x000000),
	selection_bg = string.format("#%06x", visual.bg or 0x444444),
	selection_fg = string.format("#%06x", visual.fg or normal.fg or 0xffffff),
	terminal_colors = terminal_colors,
}

-- Output JSON
print(vim.json.encode(palette))
