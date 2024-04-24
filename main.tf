

module "azure_devops_project" {
  source                      = "./modules/azure_devops_project"
  azuredevops_org_service_url = var.azuredevops_org_service_url
  project_name                = "NewCustomerProject"
}

variable "azuredevops_org_service_url" {
  description = "The URL for the Azure DevOps organization"
  type        = string
}

output "project_id" {
  value = module.azure_devops_project.project_id
}



