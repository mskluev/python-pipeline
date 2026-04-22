variable "name" {
  description = "Base name to use for resources"
  type        = string
}

variable "source_sns_topic_arn" {
  description = "The ARN of the source SNS topic to subscribe the queue to"
  type        = string
}

variable "lambda_s3_bucket" {
  description = "S3 bucket containing the lambda deployment package"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key for the lambda deployment package"
  type        = string
}

variable "lambda_handler" {
  description = "Handler function for the lambda"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the lambda"
  type        = string
  default     = "python3.12"
}

variable "lambda_environment_variables" {
  description = "Environment variables for the lambda"
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "List of lambda layer ARNs to attach"
  type        = list(string)
  default     = []
}

variable "lambda_timeout" {
  description = "Timeout in seconds for the lambda function"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size for the lambda function"
  type        = number
  default     = 128
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for the SQS queue"
  type        = number
  default     = 180 # Should be at least 6x the lambda timeout
}

variable "additional_iam_policies" {
  description = "Map of additional IAM policies (JSON strings) to attach to the Lambda execution role"
  type        = map(string)
  default     = {}
}

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
