return {
  {
    'nvim-telescope/telescope.nvim', tag = 'v0.2.0',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<C-f>', builtin.find_files, { desc = 'Find files' })
      vim.keymap.set('n', '<C-g>', builtin.live_grep, { desc = 'Live grep' })
      vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'Buffers' })
      vim.keymap.set('n', '<leader>d', builtin.diagnostics, { desc = 'Find diagnostics' })
    end
  },
  {
    'nvim-telescope/telescope-ui-select.nvim',
    config = function()
      require("telescope").setup {
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
            }
          }
        }
      }
      require("telescope").load_extension("ui-select")
    end
  },
}
