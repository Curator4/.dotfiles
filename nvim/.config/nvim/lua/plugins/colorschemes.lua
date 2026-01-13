-- All colorscheme plugins for theme switcher
return {
	-- Catppuccin (Latte for light theme)
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				transparent_background = true,
				flavour = "auto", -- latte, frappe, macchiato, mocha
			})
		end,
	},

	-- Everforest (Dark Green)
	{
		"sainnhe/everforest",
		priority = 1000,
		config = function()
			vim.g.everforest_background = "hard" -- 'hard', 'medium', 'soft'
			vim.g.everforest_transparent_background = 1
		end,
	},

	-- Ashen (Reddish/Orange)
	{
		"ficcdaf/ashen.nvim",
		priority = 1000,
	},

	-- Iceberg (Blue/Azure)
	{
		"cocopon/iceberg.vim",
		priority = 1000,
	},

	-- Nord (Blue/Azure alternative)
	{
		"shaunsingh/nord.nvim",
		priority = 1000,
		config = function()
			vim.g.nord_transparent = true
		end,
	},

	-- Neon (Cyberpunk)
	{
		"rafamadriz/neon",
		priority = 1000,
		config = function()
			vim.g.neon_style = "dark"
			vim.g.neon_transparent = true
		end,
	},

	-- Lavender (Purple)
	{
		"jthvai/lavender.nvim",
		url = "https://codeberg.org/jthvai/lavender.nvim",
		priority = 1000,
	},

	-- Lackluster (Grey/Monochrome)
	{
		"slugbyte/lackluster.nvim",
		priority = 1000,
	},

	-- Gruvbox (Retro/Warm)
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup({
				transparent_mode = true,
			})
		end,
	},
}
