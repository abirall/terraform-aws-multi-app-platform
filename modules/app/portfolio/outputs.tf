output "service_name" {
  description = "Name of the ECS service."
  value       = local.service_name
}

output "service_arn" {
  description = "ARN of the ECS service."
  value       = aws_ecs_service.portfolio.id
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = aws_ecs_task_definition.portfolio.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group used by the portfolio ECS task."
  value       = aws_cloudwatch_log_group.portfolio.name
}
