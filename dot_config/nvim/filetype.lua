vim.filetype.add({
  extension = {
    mdx = "markdown.mdx",
    gotmpl = "gotmpl",
    tfvars = "terraform-vars",
  },
  filename = {
    ["go.work"] = "gowork",
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    [".gitlab-ci.yml"] = "yaml.gitlab",
  },
  pattern = {
    ["*.go%.tmpl"] = "gotmpl",
    ["docker%-compose%..*%.ya?ml"] = "yaml.docker-compose",
    [".*/%.gitlab%-ci%.yml"] = "yaml.gitlab",
    [".*/%.gitlab/ci/.*%.ya?ml"] = "yaml.gitlab",
    ["values%.ya?ml"] = "yaml.helm-values",
    ["values%..*%.ya?ml"] = "yaml.helm-values",
  },
})
