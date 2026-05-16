if vim.bo.filetype ~= "markdown.mdx" then return end
-- MDX filetype settings
vim.bo.commentstring = "{/* %s */}"
