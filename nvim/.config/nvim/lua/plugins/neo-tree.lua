return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("neo-tree").setup({
				filesystem = {
					filtered_items = {
						visible = false, -- Hidden files hidden by default
						hide_dotfiles = true,
						hide_gitignored = true,
					},
				},
			})

			vim.keymap.set("n", "<leader>e", ":Neotree filesystem reveal left<CR>", { desc = "Show Filetree" })
			vim.keymap.set("n", "<leader>g", ":Neotree float git_status git_base=main<CR>", { desc = "Git Status" })
		end,
	},
}
