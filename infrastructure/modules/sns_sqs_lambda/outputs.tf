output "destination_sns_topic_arn" {
  description = "The ARN of the destination SNS topic"
  value       = aws_sns_topic.destination.arn
}

output "sqs_queue_arn" {
  description = "The ARN of the main SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda IAM execution role"
  value       = aws_iam_role.lambda.arn
}
