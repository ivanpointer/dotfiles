require("aerial").setup({
    layout = {
        max_width = { 128, 0.2 },
        min_width = 60
    }
})

require("telescope").load_extension("aerial")

vim.keymap.set("n", "<leader>sf", require("telescope").extensions.aerial.aerial, {})
vim.keymap.set("n", "<leader>sv", "<cmd>AerialOpen!<CR>")
vim.keymap.set("n", "<leader>st", "<cmd>AerialToggle!<CR>")
