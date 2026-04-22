# Data sources for current account/region
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Destination SNS Topic
resource "aws_sns_topic" "destination" {
  name = "${var.name}-destination"
}

# Dead-Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.name}-dlq"
}

# Main SQS Queue
resource "aws_sqs_queue" "main" {
  name                       = "${var.name}-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.main.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.source_sns_topic_arn
          }
        }
      }
    ]
  })
}

# SNS Subscription to SQS
resource "aws_sns_topic_subscription" "source_to_sqs" {
  topic_arn            = var.source_sns_topic_arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.main.arn
  raw_message_delivery = true
}

# Lambda Execution Role
resource "aws_iam_role" "lambda" {
  name                 = "${var.name}-lambda-role"
  permissions_boundary = var.permissions_boundary

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda Basic Execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Access
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda X-Ray Access
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

# Lambda SQS Receive and SNS Publish Policy
resource "aws_iam_policy" "lambda_sqs_sns" {
  name = "${var.name}-lambda-sqs-sns"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.destination.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_sns" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_sqs_sns.arn
}

# Additional IAM Policies
resource "aws_iam_policy" "additional" {
  for_each = var.additional_iam_policies

  name   = "${var.name}-policy-${each.key}"
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = aws_iam_policy.additional

  role       = aws_iam_role.lambda.name
  policy_arn = each.value.arn
}

# Lambda Function
resource "aws_lambda_function" "main" {
  function_name = "${var.name}-function"

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  handler = var.lambda_handler
  runtime = var.lambda_runtime
  role    = aws_iam_role.lambda.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  layers = var.lambda_layers

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.lambda_environment_variables
  }
}

# Lambda Event Source Mapping (SQS -> Lambda)
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.main.arn

  # Powertools batch processing requirements
  function_response_types = ["ReportBatchItemFailures"]
}
