vim.g.mapleader = " "

-- Q is the worst place in the universe, block it out
vim.keymap.set("n", "Q", "<nop>")

-- editor navigation
--   keep the cursor in the center of the screen while paging up and down
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
-- vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

--   keep cursor in middle when searching
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- buffer navigation
vim.keymap.set("n", "<leader>q", "<cmd>bd<CR>")
vim.keymap.set("n", "<C-S-Left>", "<cmd>bp<CR>")
vim.keymap.set("n", "<C-S-Right>", "<cmd>bn<CR>")

-- joining,yanking and cutting
vim.keymap.set("n", "J", "mzJ`z")

vim.keymap.set("x", "<leader>p", "\"_dP")

vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

vim.keymap.set("n", "<leader>d", "\"_d")
vim.keymap.set("v", "<leader>d", "\"_d")

-- formatting
vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format()
end)

-- toggle relative numbering
vim.keymap.set("n", "<leader>en", function()
    vim.opt.relativenumber = not (vim.opt.relativenumber:get())
end)

-- toggle search highlights
vim.keymap.set("n", "<leader>sh", function()
    vim.opt.hlsearch = not (vim.opt.hlsearch:get())
end)

-- clear search text
vim.keymap.set("n", "<leader>sc", "<cmd>noh<CR>")

