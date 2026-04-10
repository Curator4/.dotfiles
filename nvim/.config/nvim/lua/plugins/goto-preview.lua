return {
	"rmagatti/goto-preview",
	config = function()
		require("goto-preview").setup({
			width = 120,
			height = 25,
			border = "rounded",
		})
		vim.keymap.set("n", "gp", require("goto-preview").goto_preview_type_definition, { desc = "Preview type definition" })
		vim.keymap.set("n", "gP", require("goto-preview").goto_preview_definition, { desc = "Preview definition" })
		vim.keymap.set("n", "gq", require("goto-preview").close_all_win, { desc = "Close all preview windows" })
	end,
}
