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
  repo_meta_folder    = "config"
  main_pipieline_file = join("/", [local.repo_meta_folder, "azure-pipelines.yml"])
  output_logs_file    = "${path.root}/.terraform/${timestamp()}.log"
}



resource "azuredevops_project" "project" {
  name               = var.project_name
  description        = "Project ${var.project_name} created via Terraform"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}

data "azuredevops_git_repositories" "default_repo" {
  project_id = resource.azuredevops_project.project.id
  name       = var.project_name
}
resource "null_resource" "delete_default_repo" {
  depends_on = [azuredevops_project.project]
  provisioner "local-exec" {
    command = <<EOT
    # Check if logged into Azure DevOps
    if ! az devops project list --organization $AZDO_ORG_SERVICE_URL &> /dev/null; then
        echo "Not logged in to Azure DevOps. Attempting to log in using PAT..."
        echo $AZDO_PERSONAL_ACCESS_TOKEN | az devops login --organization $AZDO_ORG_SERVICE_UReL
    fi
    az repos delete \
      --id ${data.azuredevops_git_repositories.default_repo.repositories[0].id} \
      --organization $AZDO_ORG_SERVICE_URL \
      --project ${var.project_name} \
      --yes

    >> ${local.output_logs_file}
EOT
  }
}

resource "azuredevops_git_repository" "genesis_repo" {
  depends_on     = [null_resource.delete_default_repo]
  project_id     = azuredevops_project.project.id
  name           = "genesis"
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
  lifecycle { ignore_changes = [initialization] }
}

resource "azuredevops_git_repository_file" "main_tf_file" {
  repository_id       = azuredevops_git_repository.genesis_repo.id
  file                = "main.tf"
  content             = templatefile("${path.module}/templatetf.tftpl", { project_id = azuredevops_project.project.id })
  branch              = "refs/heads/main"
  commit_message      = "main tf file"
  overwrite_on_create = false
}
# resource "azuredevops_git_repository_file" "dockerfile" {
#   repository_id       = azuredevops_git_repository.genesis_repo.id
#   file                = "Dockerfile"
#   content             = file("${path.module}/Dockerfile")
#   branch              = "refs/heads/main"
#   commit_message      = "pipeline"
#   overwrite_on_create = false
# }
# resource "azuredevops_git_repository_file" "tfwrappper" {
#   # depends_on= [azuredevops_git_repository_branch.main_branch]
#   repository_id       = azuredevops_git_repository.genesis_repo.id
#   file                = "tfwrapper.sh"
#   content             = file("${path.module}/tfwrapper.sh")
#   branch              = "refs/heads/main"
#   commit_message      = "pipeline"
#   overwrite_on_create = false
# }

resource "azuredevops_git_repository_file" "pipeline_file" {
  repository_id       = azuredevops_git_repository.genesis_repo.id
  file                = local.main_pipieline_file
  content             = file("${path.module}/azure-pipeline-genesis.yml")
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}

resource "null_resource" "create_pipelins" {
  # working_dir = var.template_repos[index(var.template_repos.*.repo_name, each.value.name)].template_folder_path
  depends_on = [azuredevops_git_repository_file.pipeline_file]
  provisioner "local-exec" {
    command = <<eot
    # check if logged into azure devops
    if ! az devops project list --organization $azdo_org_service_url &> /dev/null; then
        echo "not logged in to azure devops. attempting to log in using pat..."
        echo $azdo_personal_access_token | az devops login --organization $azdo_org_service_url
    fi

    # check if the pipeline exists using az pipelines show
    if az pipelines show --name ${azuredevops_git_repository.genesis_repo.name} --organization $AZDO_ORG_SERVICE_URL --project ${var.project_name} &> /dev/null; then
        echo "pipeline already exists for ${azuredevops_git_repository.genesis_repo.name}. exiting." | tee >> ${local.output_logs_file}
        exit 0
    fi

    # run the command to create the pipeline
    az pipelines create \
    --name ${azuredevops_git_repository.genesis_repo.name} \
    --repository ${azuredevops_git_repository.genesis_repo.name} \
    --repository-type tfsgit \
    --organization $AZDO_ORG_SERVICE_URL \
    --yaml-path ${local.main_pipieline_file} \
    --project ${var.project_name} \
    >> ${local.output_logs_file}
eot
  }
}

output "project_id" {
  value = azuredevops_project.project.id
}