output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB, for alias records defined outside this module."
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group attached to the ALB. Use as the ingress source for backend instances."
  value       = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "Target group ARN keyed by ECS service route name."
  value       = { for service_name, target_group in aws_lb_target_group.this : service_name => target_group.arn }
}
