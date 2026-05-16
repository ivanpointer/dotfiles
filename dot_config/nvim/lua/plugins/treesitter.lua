return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		-- Treesitter
		local config = require("nvim-treesitter.config")
		config.setup({
			ensure_installed = {
				-- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
				"bash",
				"zsh",
				"lua",
				"make",
				"nix",
				"dockerfile",
				"gitignore",
				"git_config",

				"go",
				"gomod",
				"gosum",
				"gotmpl",
				"gowork",

				"python",

				"sql",

				"proto",

				"hcl", -- terraform

				"yaml",
				"toml",
				"json5",
				"markdown",
				"diff",

				"css",
				"scss",
				"javascript",
				"typescript",
				"html",
			},
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
}
