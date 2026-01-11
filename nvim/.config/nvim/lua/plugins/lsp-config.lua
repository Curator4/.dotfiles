return {
	{
		"mason-org/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls", -- lua
					"ts_ls", -- javascript/typescript
					"pyright", -- python
					"bashls", -- bash/zsh
					"gopls", -- go
					"html", -- html
					"cssls", -- css
					"marksman", -- markdown
					"jsonls", -- json
					"yamlls", -- yaml
					"dockerls", -- dockerfile
					"sqlls", -- sql
				},
				handlers = {
					function(server_name)
						vim.lsp.config(server_name, {})
						vim.lsp.enable(server_name)
					end,
				},
			})

			-- LSP keymaps (apply to all servers)
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
			vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
			vim.keymap.set("n", "<leader>vd", function()
				vim.cmd("vsplit")
				vim.lsp.buf.definition()
			end, { desc = "Open definition in vertical split" })
			vim.keymap.set("n", "<leader>sd", function()
				vim.cmd("split")
				vim.lsp.buf.definition()
			end, { desc = "Open definition in horizontal split" })
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
			vim.keymap.set("n", "<leader>k", function()
				local _, winnr = vim.diagnostic.open_float()
				if winnr then
					vim.api.nvim_set_current_win(winnr)
				end
			end, { desc = "Show diagnostic" })
		end,
	},
	{
		"neovim/nvim-lspconfig",
	},
}
