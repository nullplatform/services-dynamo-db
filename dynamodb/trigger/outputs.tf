output "trigger_id" {
  value       = aws_lambda_event_source_mapping.trigger.uuid
  description = "AWS identifier of the event source mapping"
}

output "function_name" {
  value       = var.function_name
  description = "Lambda function this trigger invokes"
}

output "function_alias_arn" {
  value       = data.aws_lambda_function.target.arn
  description = "ARN of the alias the trigger points at"
}
