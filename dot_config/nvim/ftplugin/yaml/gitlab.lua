if vim.bo.filetype ~= "yaml.gitlab" then return end
-- GitLab CI YAML filetype settings
vim.bo.commentstring = "# %s"
