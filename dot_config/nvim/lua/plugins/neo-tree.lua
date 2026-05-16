return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "antosha417/nvim-lsp-file-operations",
      "s1n7ax/nvim-window-picker",
    },
    lazy = false, -- neo-tree will lazily load itself
    config = function()
      -- Neotree
      require("neo-tree").setup({
        window = {
          mappings = {
            ['f'] = 'none', -- Default 'f' collides with telescope, remap find to '/'
            ['/'] = 'fuzzy_finder',
          }
        },
        source_selector = {
          winbar = true
        }
      })
    end
  }
}
