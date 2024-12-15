-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.5',
        -- or                          , branch = '0.1.x',
        requires = {
            { 'nvim-lua/plenary.nvim' },
        }
    }

    -- find more at: https://dotfyle.com/neovim/colorscheme/top
    --  Be sure to update in after/plugin/colors.lua
    use({
        'folke/tokyonight.nvim',
        as = 'tokyonight',
        config = function()
            vim.cmd('colorscheme tokyonight-night')
        end
    })

    use({
        'Mofiqul/dracula.nvim',
        as = 'dracula',
        config = function()
            vim.cmd('colorscheme dracula')
        end
    })

    -- Treesitter (better syntax highlighting)
    use {
        'nvim-treesitter/nvim-treesitter',
        run = function()
            local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
            ts_update()
        end,
    }

    use('nvim-tree/nvim-web-devicons')

    -- navigation
    use('theprimeagen/harpoon')

    -- Undotree
    use('mbbill/undotree')

    -- git
    use('tpope/vim-fugitive')
    use('lewis6991/gitsigns.nvim')

    -- ui
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    }


    use {
        'rcarriga/nvim-notify'
    }

    use {
        'nvim-tree/nvim-tree.lua',
        requires = {
            'nvim-tree/nvim-web-devicons',
        },
    }

    use {
        'stevearc/aerial.nvim'
    }

    -- using packer.nvim
    use { 'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons' }

    -- lsp-zero
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            --- Uncomment the two plugins below if you want to manage the language servers from neovim
            { 'williamboman/mason.nvim' },
            { 'williamboman/mason-lspconfig.nvim' },

            -- LSP Support
            { 'neovim/nvim-lspconfig' },
            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },
            { 'hrsh7th/cmp-nvim-lsp' },
            { 'L3MON4D3/LuaSnip' },
        }
    }

    -- dev utils
    use {
        'folke/trouble.nvim',
        'folke/todo-comments.nvim'
    }

    use {
        'ray-x/guihua.lua',
    }

    -- debugging
    use {
        'mfussenegger/nvim-dap',
        'theHamsta/nvim-dap-virtual-text'
    }

    -- go
    use {
        'ray-x/go.nvim',
        'leoluz/nvim-dap-go',
        ft = "go",
        requires = { 'mfussenegger/nvim-dap' },
        config = function(_, opts)
            require("dap-go").setup(opts)
        end
    }

    use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }

    -- utilities
    use {
        "folke/which-key.nvim",
        config = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
            require("which-key").setup {
                -- your configuration comes here
                -- or leave it empty to use the default settings
                -- refer to the configuration section below
            }
        end
    }

    -- tmux integration
    use {
        'christoomey/vim-tmux-navigator'
    }
end)
