return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
      require('telescope').setup{
        extensions = {
          fzf = {}
        }
      }

      local builtin = require("telescope.builtin")

      vim.keymap.set("n", "<leader>fd", builtin.find_files)
      vim.keymap.set("n", "<leader>fD", function()
        builtin.find_files({
          hidden = true
        })
      end)

      vim.keymap.set("n", "<leader>fg", builtin.live_grep)
      vim.keymap.set("n", "<leader>fG", function()
        builtin.live_grep({
          additional_args = function(_)
            return { "--hidden" }
          end
        })
      end)

      vim.keymap.set("n", "<leader>fb", builtin.buffers)
      vim.keymap.set("n", "<leader>fh", builtin.help_tags)
    end
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function ()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        -- https://github.com/nvim-treesitter/nvim-treesitter
          ensure_installed = { "lua", "javascript", "html", "css", "php", "go", "json", "sql" },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },
        })
    end
 },

 {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

  {
    'mbbill/undotree'
  },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 60,
        },
      })

      vim.keymap.set("n", "<leader>tt", ":NvimTreeToggle<CR>")
      vim.keymap.set("n", "<leader>tf", ":NvimTreeFocus<CR>")
      vim.keymap.set("n", "<leader>tF", ":NvimTreeFindFile<CR>")
      vim.keymap.set("n", "<leader>tc", ":NvimTreeCollapse<CR>")
    end,
  },

  {
		"tpope/vim-fugitive",
		cmd = "Git",
	},

  -- Bits for LSP
  {
    'williamboman/mason-lspconfig.nvim',
    lazy = false,
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/nvim-cmp',
      'williamboman/mason.nvim',
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        -- https://github.com/williamboman/mason-lspconfig.nvim?tab=readme-ov-file#available-lsp-servers
        ensure_installed = { "lua_ls", "ltex", "typos_lsp", "terraformls", "tflint", "sqlls", "gopls", "golangci_lint_ls", "buf_ls", "intelephense", "volar", "tailwindcss" }
      })
    end
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      local lspconfig = require("lspconfig")

      lspconfig.lua_ls.setup({})
      lspconfig.ltex.setup({})
      lspconfig.typos_lsp.setup({})

      lspconfig.terraformls.setup({})
      lspconfig.tflint.setup({})

      lspconfig.sqlls.setup({})

      lspconfig.gopls.setup({})
      lspconfig.golangci_lint_ls.setup({})
      lspconfig.buf_ls.setup({})

      lspconfig.intelephense.setup({})
      lspconfig.volar.setup({
        -- add filetypes for typescript, javascript and vue
        filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
        init_options = {
          vue = {
            -- disable hybrid mode
            hybridMode = false,
          },
        },
      })
      lspconfig.tailwindcss.setup({})
    end
  }
}
