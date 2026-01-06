return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  opts = {
    -- add to this list for treesitter syntax
    ensure_installed = {"lua", "vim", "vimdoc", "query", "javascript", "typescript", "python", "bash", "go", "zsh", "html", "css", "markdown", "json", "yaml", "dockerfile", "gitignore", "sql", "regex"},
    highlight = { enable = true },
    indent = { enable = true },
  },
}
