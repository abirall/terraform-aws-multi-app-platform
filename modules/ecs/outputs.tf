output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "capacity_providers" {
  description = "Capacity providers configured for the ECS cluster."
  value       = local.effective_capacity_providers
}

output "ecs_instance_security_group_id" {
  description = "Security group ID for ECS instances."
  value       = aws_security_group.ecs_instances.id
}

output "ecs_autoscaling_group_name" {
  description = "Name of the ECS Auto Scaling Group."
  value       = aws_autoscaling_group.ecs.name
}

output "ecs_capacity_provider_name" {
  description = "Name of the ECS capacity provider."
  value       = aws_ecs_capacity_provider.this.name
}
