if vim.bo.filetype ~= "yaml.docker-compose" then return end
-- Docker Compose YAML filetype settings
vim.bo.commentstring = "# %s"
