terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
    env = {
      source  = "tcarreira/env"
      version = "0.2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}



variable "project_name" {
  description = "The name of the Azure DevOps project to create"
  type        = string
}
