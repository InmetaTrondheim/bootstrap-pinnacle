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

data "azuredevops_project" "project" {
  name = var.project_name
}

resource "azuredevops_git_repository" "template_repo" {
  for_each = var.template_repos

  project_id = data.azuredevops_project.project.id
  name       = each.value.repo_name
  # default_branch = "refs/heads/main"
  initialization {
    init_type   = each.value.init_type
    source_type = each.value.init_type == "Import" ? "Git" : null
    source_url  = each.value.init_type == "Import" ? each.value.source_url : null
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "azuredevops_git_repository_file" "pipeline_file" {
  for_each            = azuredevops_git_repository.template_repo
  depends_on          = [null_resource.push_repo, ]

  repository_id       = each.value.id
  file                = local.main_pipieline_file
  content             = file("${path.module}/azure-pipelines.yml")
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}
resource "azuredevops_git_repository_file" "pipeline_file_template" {
  for_each            = azuredevops_git_repository.template_repo
  depends_on          = [null_resource.push_repo, ]

  repository_id       = each.value.id
  file                = join("/", [local.repo_meta_folder, "earthly-install-template.yml"])
  content             = <<EOF
steps:
  - script: |
      # Check if Earthly is installed and install if not
      if ! type earthly >/dev/null 2>&1; then
        sudo /bin/sh -c 'wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly && chmod +x /usr/local/bin/earthly && /usr/local/bin/earthly bootstrap --with-autocomplete'
      fi
	EOF
  branch              = "refs/heads/main"
  commit_message      = "pipeline"
  overwrite_on_create = false
}
resource "azuredevops_git_repository_file" "earthfile" {
  for_each            = azuredevops_git_repository.template_repo
  depends_on          = [null_resource.push_repo, ]

  repository_id       = each.value.id
  file                = "Earthfile"
  content             = <<EOF
# Earthfile

# Base setup with all necessary dependencies
VERSION 0.8
FROM earthly/earthly:latest
WORKDIR /code
COPY . .

validate-repo-setup:
    # probobly make this a import from a shared repo
    RUN echo setting up git hooks
    RUN echo checking that expected earthly targets exist: [build, immediate-tests, publish, comprehensive-tests, deploy]
    RUN echo checking that output of build is a docker image
 
# Build target
build:
    RUN echo running \"BUILD  +build\"

# Immediate tests target
immediate-tests:
    RUN echo running \"BUILD  +unit\"
    RUN echo running \"BUILD  +scan-secrets\"

# Publish target
publish:
    RUN echo running \"BUILD  +scan-secrets\"

# Comprehensive tests target
comprehensive-tests:
    RUN echo running \"BUILD  +integration-test\"
    RUN echo running \"BUILD  +e2e-test\"

# Deployment target
deploy:
    RUN echo running \"BUILD  +deploy\"
EOF
  branch              = "refs/heads/main"
  commit_message      = "earthfile"
  overwrite_on_create = false
}



resource "null_resource" "push_repo" {
  for_each = { for r in azuredevops_git_repository.template_repo : r.name => r if r.initialization[0].init_type == "Uninitialized" }

  provisioner "local-exec" {
    working_dir = var.template_repos[each.value.name].template_folder_path
    command     = <<EOT
    #push to the repo from azuredevops_git_repository.template_repo
    mkdir -p ~/.ssh && touch ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts
    ssh-keygen -F ssh.dev.azure.com || ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts

    git remote add origin ${replace(each.value.web_url, "https://", "https://$AZDO_PERSONAL_ACCESS_TOKEN@")}

    git config --global user.email "ci@pipeline.com" 
    git config --global user.name "genesis pipeline"
    git checkout -b main 

    git add .
    git commit -m "Initial commit"
    git push origin main
    sleep 3
EOT
  }
}

resource "null_resource" "az_login" {
  depends_on = [null_resource.push_repo, azuredevops_git_repository_file.pipeline_file]
  provisioner "local-exec" {
    command = <<EOT
    # Check if logged into Azure DevOps
    if ! az devops project list --organization $AZDO_ORG_SERVICE_URL &> /dev/null; then
        echo "Not logged in to Azure DevOps. Attempting to log in using PAT..."
        if echo $AZDO_PERSONAL_ACCESS_TOKEN | az devops login --organization $AZDO_ORG_SERVICE_URL; then
            echo "Logged in successfully."
        else
            echo "Failed to log in. Check if the PAT is correct and active."
            exit 1
        fi
    fi
EOT
  }
}

resource "null_resource" "create_pipelins" {
  for_each = azuredevops_git_repository.template_repo

  depends_on = [null_resource.az_login, null_resource.push_repo, azuredevops_git_repository_file.pipeline_file]
  provisioner "local-exec" {
    command = <<EOT
    sleep 3
    set -x  # This enables a more verbose shell output to trace commands.
    
    echo "Checking if pipeline ${each.key} exists..."
    az pipelines show --name ${each.key} --organization $AZDO_ORG_SERVICE_URL --project ${var.project_name}
    if [ $? -eq 0 ]; then
        echo "${each.key} pipeline exists. Exiting."
        exit 0
    else
        echo "${each.key} pipeline does not exist. Attempting to create..."
        az pipelines create \
        --name ${each.key} \
        --repository ${each.value.name} \
        --repository-type tfsgit \
        --organization $AZDO_ORG_SERVICE_URL \
        --yaml-path ${local.main_pipieline_file} \
        --branch main \
        --project ${var.project_name}   
	if [ $? -ne 0 ]; then
          echo "Failed to create pipeline backend."
        fi
    fi

    set +x  # Turn off verbose output
EOT
  }
}

output "project_id" {
  value = data.azuredevops_project.project.id
}
