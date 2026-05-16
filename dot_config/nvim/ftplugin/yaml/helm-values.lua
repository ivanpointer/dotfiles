if vim.bo.filetype ~= "yaml.helm-values" then return end
-- Helm values YAML filetype settings
vim.bo.commentstring = "# %s"
