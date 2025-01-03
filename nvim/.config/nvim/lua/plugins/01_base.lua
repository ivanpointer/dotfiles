return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("telescope").setup({
        extensions = {
          fzf = {},
        },
      })

      local builtin = require("telescope.builtin")

      vim.keymap.set("n", "<leader>fd", builtin.find_files)
      vim.keymap.set("n", "<leader>fD", function()
        builtin.find_files({
          hidden = true,
        })
      end)

      vim.keymap.set("n", "<leader>fg", builtin.live_grep)
      vim.keymap.set("n", "<leader>fG", function()
        builtin.live_grep({
          additional_args = function(_)
            return { "--hidden" }
          end,
        })
      end)

      vim.keymap.set("n", "<leader>fb", builtin.buffers)
      vim.keymap.set("n", "<leader>fh", builtin.help_tags)
    end,
  },

  {
    "nvim-telescope/telescope-ui-select.nvim",
    config = function()
      -- This is your opts table
      require("telescope").setup({
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({
              -- even more opts
            }),

            -- pseudo code / specification for writing custom displays, like the one
            -- for "codeactions"
            -- specific_opts = {
            --   [kind] = {
            --     make_indexed = function(items) -> indexed_items, width,
            --     make_displayer = function(widths) -> displayer
            --     make_display = function(displayer) -> function(e)
            --     make_ordinal = function(e) -> string
            --   },
            --   -- for example to disable the custom builtin "codeactions" display
            --      do the following
            --   codeactions = false,
            -- }
          },
        },
      })
      -- To get ui-select loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      require("telescope").load_extension("ui-select")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        -- https://github.com/nvim-treesitter/nvim-treesitter
        ensure_installed = { "lua", "javascript", "html", "css", "php", "go", "json", "sql" },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
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
    "mbbill/undotree",
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
    "L3MON4D3/LuaSnip",
    dependencies = {
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },
  {
    "hrsh7th/nvim-cmp",
    config = function()
      local cmp = require("cmp")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          -- { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        -- https://github.com/williamboman/mason-lspconfig.nvim?tab=readme-ov-file#available-lsp-servers
        ensure_installed = {
          "lua_ls",
          "bashls",
          "ltex",
          "typos_lsp",
          "terraformls",
          "tflint",
          "sqlls",
          "gopls",
          "golangci_lint_ls",
          "buf_ls",
          "intelephense",
          "ts_ls",
          "volar",
          "tailwindcss",
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- LUA
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
      })

      -- BASH
      lspconfig.bashls.setup({
        capabilities = capabilities,
      })

      -- TEXT/GENERAL
      lspconfig.ltex.setup({})
      lspconfig.typos_lsp.setup({})

      -- TERRAFORM
      lspconfig.terraformls.setup({})
      lspconfig.tflint.setup({})

      -- SQL
      lspconfig.sqlls.setup({})

      -- GOLANG
      lspconfig.gopls.setup({})
      lspconfig.golangci_lint_ls.setup({})
      lspconfig.buf_ls.setup({})

      -- PHP
      lspconfig.intelephense.setup({})

      -- TYPESCRIPT
      lspconfig.ts_ls.setup({})
      lspconfig.volar.setup({
        -- add filetypes for typescript, javascript and vue
        filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
        init_options = {
          vue = {
            -- disable hybrid mode
            hybridMode = false,
          },
        },
      })
      lspconfig.tailwindcss.setup({})

      -- FORMATTERS
      lspconfig.stylua.setup({})

      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
    end,
  },

  {
    "nvimtools/none-ls.nvim",
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.stylua,
        },
      })

      vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
    end,
  },

  -- DEBUGGING
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      vim.keymap.set("n", "<leader>dt", dap.toggle_breakpoint, {})
      vim.keymap.set("n", "<leader>dc", dap.continue, {})
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  },
}
