terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "commit_sha" {
  type        = string
  description = "Git commit SHA for lambda deployment"
  default     = "latest"
}

# Add module calls here
