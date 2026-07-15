terraform {

  required_version = ">= 1.5.0"

  cloud {
    organization = "my-terraform-interview"
    workspaces {
      name = "tenantforge-azure-dev"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}