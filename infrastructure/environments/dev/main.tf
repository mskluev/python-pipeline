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

data "aws_caller_identity" "current" {}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "commit_sha" {
  type        = string
  description = "Git commit SHA for lambda deployment"
  default     = "latest"
}

resource "aws_s3_bucket" "working_bucket" {
  bucket = "mskluev-test-${data.aws_caller_identity.current.account_id}"
}

# Add module calls here

variable "permissions_boundary" {
  description = "aws permissions boundary"
  type        = string
}

variable "subnet_ids" {
  description = "aws subnet ids"
  type        = list(string)
}

variable "security_group_ids" {
  description = "aws security group ids"
  type        = list(string)
}

variable "model_s3_path" {
  description = "S3 path to the model.tar.gz file"
  type        = string
}

variable "sagemaker_iam_role" {
  description = "ARN of the sagemaker iam role to use"
  type        = string
}

variable "triton_image_uri" {
  description = "Triton docker image"
  type        = string
}

module "sagemaker_skill" {
  source = "../../modules/sagemaker_skill"

  permissions_boundary = var.permissions_boundary
  subnet_ids           = var.subnet_ids
  security_group_ids   = var.security_group_ids
  model_s3_path        = var.model_s3_path
  sagemaker_iam_role   = var.sagemaker_iam_role
  triton_image_uri     = var.triton_image_uri
  working_bucket       = aws_s3_bucket.working_bucket.bucket
}
