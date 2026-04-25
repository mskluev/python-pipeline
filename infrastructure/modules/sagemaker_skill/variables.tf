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

variable "working_bucket" {
  description = "bucket for storage"
  type        = string
}

# SageMaker
variable "model_s3_path" {
  description = "S3 path to the model.tar.gz file (e.g., s3://my-models-bucket/demo/identity/identity.tar.gz)"
  type        = string
}

variable "sm_instance_type" {
  description = "EC2 instance type for the endpoint (e.g., ml.m5.large, ml.g4dn.xlarge)"
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_iam_role" {
  description = "ARN of the sagemaker iam role to use"
  type        = string
}

variable "triton_image_uri" {
  # `nvcr.io/nvidia/tritonserver:25.09-py3` re-tagged and pushed to ECR
  description = "Triton docker image"
  type        = string

}
