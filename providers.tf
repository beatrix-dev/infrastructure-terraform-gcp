terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "Allthree"
    workspaces {
      name = "infrastructure-dev-gcp"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "aws" {
  region = var.aws_region
}
