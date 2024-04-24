terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
  }
}

provider "azuredevops" {
  org_service_url = var.azuredevops_org_service_url
}

variable "project_name" {
  description = "The name of the Azure DevOps project to create"
  type        = string
}

variable "azuredevops_org_service_url" {
  description = "The URL for the Azure DevOps organization"
  type        = string
}

variable "template_repos" {
  description = "List of repositories to be created"
  type        = map(object({
    repo_name     = string
    init_type     = string
    source_type   = string
    source_url    = string
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

  project_id    = azuredevops_project.project.id
  name          = each.value.repo_name
  initialization {
    init_type   = each.value.init_type
    source_type = each.value.source_type
    source_url  = each.value.source_url
  }
}

resource "azuredevops_git_repository_file" "pipeline_file" {
  for_each = azuredevops_git_repository.template_repo
  repository_id       = each.value.id
  file                = "azure-pipelines.yml"
  content             = file("${path.module}/azure-pipelines.yml")
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}

output "project_id" {
  value = azuredevops_project.project.id
}

