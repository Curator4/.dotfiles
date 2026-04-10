return {
	"goolord/alpha-nvim",
	event = "VimEnter",
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")
		local cdir = vim.fn.getcwd()

		-- Set header
		dashboard.section.header.val = {
			"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠐⢀⠠⡠⡰⡐⢔⠰⡡⡂⢄⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣜⢖⢜⢜⢜⢌⠆⡎⡪⡊⡆⡕⢅⢕⢌⠆⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡥⣜⢮⢢⢣⠱⡑⢵⣱⠡⡣⢹⢢⠣⡱⡨⠢⡣⡱⡐⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⢀⠮⣯⡺⣵⠱⣕⢕⢍⢖⡌⣗⠜⡌⢞⡝⡼⡨⡣⡊⡢⡱⡑⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠆⢸⣪⢯⢞⣕⢵⡫⣗⡥⣝⢺⢸⢸⠨⣎⢯⡲⣜⠬⡢⡱⡨⡂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠁⣸⣪⢯⢯⣚⢮⢺⣱⣝⡮⣯⢳⡫⡕⢜⣕⡇⡶⣫⡳⡨⠢⡪⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠐⣗⣯⡳⡳⣹⢱⡳⡕⣯⡳⡕⣝⢮⢢⠳⡕⣏⢞⢼⢱⡑⢕⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠠⠀⢱⣳⣫⣟⢎⢇⢧⢫⡲⡕⡇⡗⣝⡆⡏⡮⢪⣫⣪⡗⣎⠪⢦⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⢸⢚⢮⡪⡎⡧⡳⡱⡣⡳⣱⢹⡚⡮⣣⢣⢣⡳⣵⣣⢣⢫⢸⢊⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡸⢀⣟⣞⡜⣎⢮⢣⡫⡺⣸⢢⢫⢯⡪⡎⡧⡇⡷⡳⣕⢣⣣⢫⡸⠀⡀⡄⡔⡔⡕⡕⣕⢥⢀⠀⠀⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡇⢰⣳⡳⡽⡜⣜⢕⢵⢹⢜⢎⢇⢗⢧⢳⡕⡇⣟⢽⣪⢗⣞⠾⡔⡝⣜⢜⣜⢜⢜⢕⢇⢧⢣⡣⢄⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡇⢘⡮⡾⣕⢿⢜⡎⡧⣗⣗⢵⡹⣱⢝⢮⢮⣳⣝⣗⡽⡝⡜⣜⣜⡞⡮⡳⣕⢯⢮⡪⡪⡪⡪⡪⡕⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡇⡯⣞⡽⡮⣫⢗⣗⠱⠑⣗⣗⡝⣜⢮⢧⡳⣷⣳⣗⣗⢷⢽⡞⡎⡯⡹⡹⡸⡩⡣⡣⡣⡣⡣⡣⣓⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡅⡯⣮⡻⡮⡳⡯⣺⡂⢃⠈⠺⣺⣺⢷⢝⣞⣮⣳⣳⣺⢽⣫⢮⢮⠮⢮⢪⣪⡪⡪⡪⡳⡹⡪⡪⡲⡀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⣝⡽⣺⣺⠑⢯⣻⡪⡇⠀⢂⣴⣟⣗⡿⣽⣺⢞⣞⣮⡫⣏⢇⣇⡧⣯⡺⣜⢜⢮⢫⢗⡵⣕⢵⢱⢱⢡⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⣞⡽⣺⠊⠀⢹⣜⢺⢅⢰⣟⣗⡷⡯⣯⢷⡯⣟⢾⣺⣞⢽⢚⢜⢜⢜⢎⢾⢾⣺⣞⢾⣺⣪⢯⣎⢎⢎⠆⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⣗⡯⡗⠀⡂⠀⢗⡅⣟⣯⢷⡯⡿⡽⣞⣯⢿⢽⢝⣗⣵⢱⢱⡗⡕⡕⡕⡕⡭⣳⢽⢽⣺⣺⣝⣎⢇⢯⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⠀⡧⣟⠀⠐⠀⡀⠸⣝⣽⢾⢯⣟⡯⣟⢷⢽⢯⢯⣻⡺⣺⢜⡜⡎⡎⡎⡎⡎⡎⡎⡯⣟⣞⣞⣜⢞⡜⡆⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⢠⣹⡕⠀⠀⠘⡄⠀⠱⣯⣻⢽⣳⢯⢯⣻⡽⣳⢽⣺⢽⢵⢫⢪⢪⢪⢪⢪⠪⡎⡎⡺⣽⣺⣺⣺⡳⡇⠀⠀⠀⠀⠀",
			"⠀⠀⠀⠀⠀⠀⠀⢸⣺⠂⠡⠀⠀⠘⠄⡰⣳⢯⣻⣺⢽⣻⢮⢯⢾⢽⣺⢽⣺⣕⢕⢕⢵⢱⢱⢱⢱⢱⢱⣻⣺⣺⣺⠚⠁⠀⠀⠀⠀⠀",
		}

		-- Set menu
		dashboard.section.buttons.val = {
			dashboard.button("f", "󰈞  Find file", ":Telescope find_files <CR>"),
			dashboard.button("e", "󰙅  File tree", ":Neotree toggle<CR>"),
			dashboard.button("r", "󰋚  Recent files", ":Telescope oldfiles <CR>"),
			dashboard.button("g", "󰱼  Find text", ":Telescope live_grep <CR>"),
			dashboard.button("U", "󰚰  Update plugins", ":Lazy update<CR>"),
			dashboard.button("q", "󰩈  Quit", ":qa<CR>"),
		}

		-- Recent files section
		local mru = {
			type = "group",
			val = {
				{
					type = "text",
					val = "Recent Files",
					opts = {
						hl = "SpecialComment",
						shrink_margin = false,
						position = "center",
					},
				},
				{ type = "padding", val = 1 },
				{
					type = "group",
					val = function()
						return { require("alpha.themes.theta").mru(0, cdir, 5) }
					end,
					opts = { shrink_margin = false },
				},
			},
		}

		-- Set footer
		dashboard.section.footer.val = "Dynasty 🔥🩸"

		-- Custom layout
		dashboard.config.layout = {
			{ type = "padding", val = 2 },
			dashboard.section.header,
			{ type = "padding", val = 2 },
			dashboard.section.buttons,
			{ type = "padding", val = 1 },
			mru,
			{ type = "padding", val = 1 },
			dashboard.section.footer,
		}

		-- Send config to alpha
		alpha.setup(dashboard.config)

		-- Disable folding on alpha buffer
		vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])

		-- Keymap to return to dashboard
		vim.keymap.set("n", "<leader>a", ":Alpha<CR>", { desc = "Dashboard" })
	end,
	dependencies = { "nvim-tree/nvim-web-devicons" },
}
