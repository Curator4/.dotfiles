return {
  -- Add theme plugins here (they'll be auto-downloaded)
  { "ellisonleao/gruvbox.nvim" },
  { "rose-pine/neovim", name = "rose-pine" },
  { "folke/tokyonight.nvim" },
  { "catppuccin/nvim", name = "catppuccin" },
  { "rebelot/kanagawa.nvim" },
  { "EdenEast/nightfox.nvim" },

  -- Osaka jade theme (uses bamboo colorscheme from Omarchy)
  {
    "ribru17/bamboo.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true, -- Enable transparent background
      terminal_colors = true,
      style = "vulgaris", -- multiplex, vulgaris, light
    },
  },

  -- Alternative: Solarized Osaka
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
      terminal_colors = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  -- Configure which theme to use (change this one line to switch themes)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "bamboo", -- Options: bamboo (osaka jade), solarized-osaka, gruvbox, rose-pine, tokyonight, catppuccin, kanagawa, nightfox
    },
  },

  -- Optional: Configure catppuccin variant
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
    },
  },
}
