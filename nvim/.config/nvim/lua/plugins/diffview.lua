return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		vim.keymap.set("n", "<leader>dv", function()
			if require("diffview.lib").get_current_view() then
				vim.cmd("DiffviewClose")
			else
				vim.cmd("DiffviewOpen")
			end
		end, { desc = "Toggle Diffview" })

		vim.keymap.set("n", "<leader>dh", ":DiffviewFileHistory %<CR>", { desc = "File history" })
	end,
}
