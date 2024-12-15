-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- following options are the default
-- each of these are documented in `:help nvim-tree.OPTION_NAME`

require("nvim-tree").setup({
    view = {
        width = 60
    }
})

vim.keymap.set("n", "<leader>pv", "<cmd> NvimTreeToggle<CR>")
vim.keymap.set("n", "<leader>pp", "<cmd> NvimTreeFocus<CR>")
vim.keymap.set("n", "<leader>ps", "<cmd> NvimTreeFindFile<CR>")
vim.keymap.set("n", "<leader>p-", "<cmd> NvimTreeCollapse<CR>")
