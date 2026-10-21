output "service_name" {
  description = "Name of the ECS service."
  value       = local.service_name
}

output "service_arn" {
  description = "ARN of the ECS service."
  value       = aws_ecs_service.web.id
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = aws_ecs_task_definition.web.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group used by the web ECS task."
  value       = aws_cloudwatch_log_group.web.name
}
