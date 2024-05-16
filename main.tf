#set the following variables 
#export AZDO_PERSONAL_ACCESS_TOKEN=<Personal Access Token>
#export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<Your Org Name>

module "azure_devops_project" {
  source       = "./modules/azure_devops_project2"
  project_name = "tfCreatedProLaptop"
}

