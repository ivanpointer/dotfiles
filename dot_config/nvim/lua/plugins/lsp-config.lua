return {
	{
		"mason-org/mason.nvim",
		opts = {},
		config = function()
			require("mason").setup()
		end,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				-- https://mason-registry.dev/registry/list
				ensure_installed = {
					"lua_ls", -- Lua
					"gopls", -- Go
					"pyright", -- Python
					"bashls", -- Bash/Zsh
					"ts_ls", -- JavaScript/TypeScript
					"html", -- HTML
					"cssls", -- CSS/SCSS
					"jsonls", -- JSON
					"yamlls", -- YAML
					"sqlls", -- SQL
					"buf_ls", -- Protobuf
					"terraformls", -- Terraform (HCL)
					"dockerls", -- Dockerfile
					"marksman", -- Markdown
					"nil_ls", -- Nix
					"taplo", -- TOML
				},
			})
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					-- Formatters
					"stylua", -- Lua
					"goimports", -- Go
					"ruff", -- Python (formatter + linter)
					"shfmt", -- Bash/Zsh
					"prettier", -- JS/TS, HTML, CSS, JSON, YAML, Markdown
					-- Linters
					"shellcheck", -- Bash/Zsh
					"eslint_d", -- JavaScript/TypeScript
					"hadolint", -- Dockerfile
					"tflint", -- Terraform
					"golangci-lint", -- Go
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			vim.lsp.enable({
				"lua_ls", -- Lua
				"gopls", -- Go
				"pyright", -- Python
				"bashls", -- Bash/Zsh
				"ts_ls", -- JavaScript/TypeScript
				"html", -- HTML
				"cssls", -- CSS/SCSS
				"jsonls", -- JSON
				"yamlls", -- YAML
				"sqlls", -- SQL
				"buf_ls", -- Protobuf
				"terraformls", -- Terraform (HCL)
				"dockerls", -- Dockerfile
				"marksman", -- Markdown
				"nil_ls", -- Nix
				"taplo", -- TOML
			})

			-- Keymaps
			vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})

			vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
		end,
	},
}
