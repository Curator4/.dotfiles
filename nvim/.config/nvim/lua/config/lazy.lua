-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "catppuccin" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})

-- Load colorscheme from theme-switcher configuration
local ok, theme_config = pcall(require, "config.colorscheme")
if ok and theme_config and theme_config.colorscheme then
	-- Set variant-specific global variables if needed
	if theme_config.variant ~= "" then
		if theme_config.colorscheme == "everforest" then
			vim.g.everforest_background = theme_config.variant
		elseif theme_config.colorscheme == "neon" then
			vim.g.neon_style = theme_config.variant
		elseif theme_config.colorscheme:match("^catppuccin") then
			vim.g.catppuccin_flavour = theme_config.variant
		end
	end

	-- Set background
	vim.opt.background = theme_config.background

	-- Apply colorscheme
	vim.cmd.colorscheme(theme_config.colorscheme)

	-- Apply transparency overrides
	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
	vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
	vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })
else
	-- Fallback to catppuccin
	vim.cmd.colorscheme("catppuccin-frappe")

	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
	vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
	vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })
end
