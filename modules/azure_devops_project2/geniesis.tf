locals {
  repo_meta_folder    = "ops"
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

resource "azuredevops_project_pipeline_settings" "example" {
  project_id = azuredevops_project.project.id

  enforce_job_scope = false
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
  project_id     = azuredevops_project.project.id
  name           = "genesis"
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
  lifecycle {
    ignore_changes = all
  }
}

resource "azuredevops_git_repository_file" "main_tf_file" {
  repository_id       = azuredevops_git_repository.genesis_repo.id
  file                = "main.tf"
  content             = templatefile("${path.module}/templatetf.tftpl", { project_name = azuredevops_project.project.name })
  branch              = "refs/heads/main"
  commit_message      = "main tf file"
  overwrite_on_create = false
}

resource "azuredevops_git_repository_file" "pipeline_file" {
  repository_id       = azuredevops_git_repository.genesis_repo.id
  file                = local.main_pipieline_file
  content             = templatefile("${path.module}/azure-pipeline-genesis.yml", { project_name = azuredevops_project.project.name })
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}


resource "azuredevops_build_definition" "example" {
  depends_on = [azuredevops_git_repository_file.pipeline_file]
  project_id = azuredevops_project.project.id
  name       = azuredevops_git_repository.genesis_repo.name

  ci_trigger {
    use_yaml = true
  }

  # schedules {
  #   branch_filter {
  #     include = ["master"]
  #     exclude = ["test", "regression"]
  #   }
  #   days_to_build              = ["Wed", "Sun"]
  #   schedule_only_with_changes = true
  #   start_hours                = 10
  #   start_minutes              = 59
  #   time_zone                  = "(UTC) Coordinated Universal Time"
  # }

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.genesis_repo.id
    branch_name = azuredevops_git_repository.genesis_repo.default_branch
    yml_path    = local.main_pipieline_file
  }

  # variable_groups = [ azuredevops_variable_group.example.id ]

  variable {
    name      = "AZDO_PERSONAL_ACCESS_TOKEN"
    value     = data.env_var.AZDO_PERSONAL_ACCESS_TOKEN.value
    is_secret = false
  }

  variable {
    name      = "AZDO_ORG_SERVICE_URL"
    value     = data.env_var.AZDO_ORG_SERVICE_URL.value
    is_secret = false
  }
}

data "env_var" "AZDO_PERSONAL_ACCESS_TOKEN" {
  id       = "AZDO_PERSONAL_ACCESS_TOKEN"
  required = true # (optional) plan will error if not found
}
data "env_var" "AZDO_ORG_SERVICE_URL" {
  id       = "AZDO_ORG_SERVICE_URL"
  required = true # (optional) plan will error if not found
}

output "project_id" {
  value = azuredevops_project.project.id
}
