terraform {

  required_version = ">= 1.5.0"

  cloud {
    organization = "my-terraform-interview"
    workspaces { 
      name = "azure-secure-devops-dev" 
    } 
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}