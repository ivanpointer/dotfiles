return {
  "stevearc/conform.nvim",
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        lua                = { "stylua" },
        go                 = { "goimports" },
        python             = { "ruff_format" },
        sh                 = { "shfmt" },
        bash               = { "shfmt" },
        javascript         = { "prettier" },
        typescript         = { "prettier" },
        javascriptreact    = { "prettier" },
        typescriptreact    = { "prettier" },
        html               = { "prettier" },
        css                = { "prettier" },
        scss               = { "prettier" },
        json               = { "prettier" },
        jsonc              = { "prettier" },
        yaml               = { "prettier" },
        markdown           = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
      },
    })
  end
}
