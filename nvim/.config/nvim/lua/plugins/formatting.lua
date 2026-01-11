return {
  'stevearc/conform.nvim',
  config = function()
    require('conform').setup({
      formatters_by_ft = {
        -- Web stuff (all use prettier)
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        css = { 'prettier' },
        html = { 'prettier' },
        json = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },

        -- Other languages
        lua = { 'stylua' },
        python = { 'ruff_format' },
        go = { 'gofmt' },
        bash = { 'shfmt' },
        sh = { 'shfmt' },
      },
      -- Format on save
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    })

    -- Manual format keymap
    vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
      require('conform').format({
        lsp_fallback = true,
        async = false,
        timeout_ms = 500,
      })
    end, { desc = 'Format file or selection' })
  end,
}
