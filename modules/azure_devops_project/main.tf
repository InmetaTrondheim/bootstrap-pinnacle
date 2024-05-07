terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
  }
}


variable "project_name" {
  description = "The name of the Azure DevOps project to create"
  type        = string
}

locals {
  pipeline_yaml_path = "azure-pipelines.yml"
  output_logs_file   = "${path.root}/.terraform/${timestamp()}.log"
}


variable "template_repos" {
  description = "List of repositories to be created"
  type = map(object({
    repo_name            = string
    init_type            = string
    source_url           = optional(string)
    template_folder_path = optional(string)
  }))
  default = {
    "frontend" = {
      repo_name   = "backend",
      init_type   = "Import",
      source_type = "Git",
      source_url  = "https://github.com/InmetaTrondheim/dotnet-template.git"
    },
    "infra" = {
      repo_name   = "infra",
      init_type   = "Import",
      source_type = "Git",
      source_url  = "https://github.com/InmetaTrondheim/terraform-azure.git"
    }
  }
}

resource "azuredevops_project" "project" {
  name               = var.project_name
  description        = "Project created via Terraform"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}

resource "azuredevops_git_repository" "template_repo" {
  for_each = var.template_repos

  project_id     = azuredevops_project.project.id
  name           = each.value.repo_name
  # default_branch = "refs/heads/main"
  initialization {
    init_type   = each.value.init_type
    source_type = each.value.init_type == "Import" ? "Git" : null
    source_url  = each.value.init_type == "Import" ? each.value.source_url : null
  }
}

resource "azuredevops_git_repository_file" "pipeline_file" {
  # for_each            = azuredevops_git_repository.template_repo
  for_each            = { for r in azuredevops_git_repository.template_repo : r.name => r if r.initialization[0].init_type != "Uninitialized" }
  repository_id       = each.value.id
  file                = local.pipeline_yaml_path
  content             = file("${path.module}/azure-pipelines.yml")
  branch              = each.value.default_branch
  commit_message      = "pipeline"
  overwrite_on_create = false
}
resource "null_resource" "push_repo" {
  for_each = { for r in azuredevops_git_repository.template_repo : r.name => r if r.initialization[0].init_type == "Uninitialized" }
  provisioner "local-exec" {
    working_dir = var.template_repos[each.value.name].template_folder_path
    command     = <<EOT
    #push to the repo from azuredevops_git_repository.template_repo
    ssh-keygen -F ssh.dev.azure.com || ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts

    git remote show origin || git remote add origin ${each.value.ssh_url}

    B64_PAT=$(printf "$(echo $AZDO_PERSONAL_ACCESS_TOKEN)" | base64)  

    git add .
    git commit -m "Initial commit"
    git -c http.extraHeader="Authorization: Basic $B64_PAT" push
EOT
  }
}

resource "null_resource" "create_pipelins" {
  for_each = azuredevops_git_repository.template_repo

  # working_dir = var.template_repos[index(var.template_repos.*.repo_name, each.value.name)].template_folder_path
  depends_on = [azuredevops_git_repository_file.pipeline_file]
  provisioner "local-exec" {
    command = <<EOT
    # Check if logged into Azure DevOps
    if ! az devops project list --organization $AZDO_ORG_SERVICE_URL &> /dev/null; then
        echo "Not logged in to Azure DevOps. Attempting to log in using PAT..."
        echo $AZDO_PERSONAL_ACCESS_TOKEN | az devops login --organization $AZDO_ORG_SERVICE_URL
    fi

    # Check if the pipeline exists using az pipelines show
    if az pipelines show --name ${each.key} --organization $AZDO_ORG_SERVICE_URL --project ${var.project_name} &> /dev/null; then
        echo "Pipeline already exists for ${var.project_name}. Exiting." | tee >> ${local.output_logs_file}
        exit 0
    fi

    # Run the command to create the pipeline
    az pipelines create \
    --name ${each.key} \
    --repository ${each.value.name} \
    --repository-type tfsgit \
    --organization $AZDO_ORG_SERVICE_URL \
    --yaml-path ${local.pipeline_yaml_path} \
    --project ${var.project_name} \
    >> ${local.output_logs_file}
EOT
  }
}

output "project_id" {
  value = azuredevops_project.project.id
}
