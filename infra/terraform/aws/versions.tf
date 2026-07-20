terraform {

  required_version = ">= 1.5.0"

  cloud {
    organization = "my-terraform-interview"
    workspaces {
      name = "tenantforge-aws-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
