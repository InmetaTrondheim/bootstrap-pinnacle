#set the following variables 
#export AZDO_PERSONAL_ACCESS_TOKEN=<Personal Access Token>
#export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<Your Org Name>

module "repo_creation" {
  source           = "./modules/repo_creation"
  bootstrap_script = "docker run -v $(pwd):/out ghcr.io/inmetatrondheim/dotnet-template:main -n tset "
  repo_host        = "azuredevops"
}

module "azure_devops_project" {
  source       = "./modules/azure_devops_project"
  project_name = "tfCreatedPro"
  template_repos = {
    "frontend" = {
      repo_name  = "frontend",
      init_type  = "Import",
      source_url = "https://github.com/InmetaTrondheim/dotnet-template.git"
    },
    "backend" = {
      repo_name            = "backend",
      init_type            = "Clean",
      template_folder_path = module.repo_creation.initialized_folder_path
    },
    "infra" = {
      repo_name  = "infra",
      init_type  = "Import",
      source_url = "https://github.com/InmetaTrondheim/terraform-azure.git"
    }
  }
}

output "project_id" {
  value = module.azure_devops_project.project_id
}

