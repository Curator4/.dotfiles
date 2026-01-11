return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons", -- optional, but recommended
    },
    config = function()
      vim.keymap.set('n', '<leader>e', ':Neotree filesystem reveal left<CR>', {desc = 'Show Filetree'})
      vim.keymap.set('n', '<leader>g', ':Neotree float git_status git_base=main<CR>', {desc = 'Git Status'})
    end
  }
}
