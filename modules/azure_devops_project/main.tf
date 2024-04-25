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
  output_logs_file= "${path.root}/.terraform/${timestamp()}.log"
}


variable "template_repos" {
  description = "List of repositories to be created"
  type = map(object({
    repo_name   = string
    init_type   = string
    source_type = string
    source_url  = string
  }))
  default = {
    "frontend" = {
      repo_name   = "backend",
      init_type   = "Import",
      source_type = "Git",
      source_url  = "https://github.com/InmetaTrondheim/dotnet-template.git"
    },
    "backend" = {
      repo_name   = "frontend",
      init_type   = "Import",
      source_type = "Git",
      source_url  = "https://github.com/InmetaTrondheim/nextjs-template.git"
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

  project_id = azuredevops_project.project.id
  name       = each.value.repo_name
  initialization {
    init_type   = each.value.init_type
    source_type = each.value.source_type
    source_url  = each.value.source_url
  }
}

resource "azuredevops_git_repository_file" "pipeline_file" {
  for_each            = azuredevops_git_repository.template_repo
  repository_id       = each.value.id
  file                = local.pipeline_yaml_path
  content             = file("${path.module}/azure-pipelines.yml")
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}

resource "null_resource" "create_pipelins" {
  for_each            = azuredevops_git_repository.template_repo
  
  depends_on = [azuredevops_git_repository_file.pipeline_file]
  provisioner "local-exec" {
    command = <<EOT
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
