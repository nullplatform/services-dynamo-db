output "table_name" {
  value       = aws_dynamodb_table.main.name
  description = "DynamoDB table name"
}

output "table_arn" {
  value       = aws_dynamodb_table.main.arn
  description = "DynamoDB table ARN"
}

output "table_id" {
  value       = aws_dynamodb_table.main.id
  description = "Internal DynamoDB table identifier"
}

output "table_region" {
  value       = var.region
  description = "AWS region where the table lives"
}

# Consumed by the trigger link to wire the stream to a Lambda function.
# Written to the service attributes by write_service_outputs so links can read
# it from the notification context instead of calling AWS.
output "stream_arn" {
  value       = aws_dynamodb_table.main.stream_arn
  description = "ARN of the table's DynamoDB stream"
}
