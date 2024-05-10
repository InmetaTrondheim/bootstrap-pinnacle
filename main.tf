#set the following variables 
#export AZDO_PERSONAL_ACCESS_TOKEN=<Personal Access Token>
#export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<Your Org Name>

module "azure_devops_project" {
  source       = "./modules/azure_devops_project2"
  project_name = "tfCreatedPro3"
}







# module "repo_creation" {
#   source       = "github.com/InmetaTrondheim/bootstrap-pinnacle//modules/repo_creation"
#   bootstrap_script = "docker run -v $(pwd):/out ghcr.io/inmetatrondheim/dotnet-template:main -n tset "
#   repo_host        = "azuredevops"
# }
# module "azure_devops_project" {
#   source       = "github.com/InmetaTrondheim/bootstrap-pinnacle//modules/azure_devops_project"
#   project_name = "tfCreatedPro3"
#   template_repos = {
#     "frontend" = {
#       repo_name  = "frontend",
#       init_type  = "Import",
#       source_url = "https://github.com/InmetaTrondheim/nextjs-template.git"
#     },
#     "backend" = {
#       repo_name            = "backend",
#       init_type            = "Uninitialized",
#       template_folder_path = module.repo_creation.initialized_folder_path
#     },
#     "infra" = {
#       repo_name  = "infra",
#       init_type  = "Import",
#       source_url = "https://github.com/InmetaTrondheim/terraform-azure.git"
#     }
#   }
# }
#
