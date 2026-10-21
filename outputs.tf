output "alb_dns_name" {
  description = "Application Load Balancer URL"
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB target group used by the lgm-web service."
  value       = module.alb.target_group_arns[var.lgm_service_route]
}

output "target_group_arns" {
  description = "ALB target group ARNs keyed by ECS service route name."
  value       = module.alb.target_group_arns
}

output "acm_domain_validation_records" {
  description = "CNAME records to create manually in Cloudflare with proxying disabled"
  value       = module.acm.domain_validation_records
}

output "website_domains" {
  description = "Normalized hostnames served by the shared ALB"
  value       = local.website_domains
}

output "private_hosted_zone_id" {
  description = "Route 53 private hosted-zone ID associated with the VPC."
  value       = aws_route53_zone.private.zone_id
}

output "private_hosted_zone_name" {
  description = "Internal DNS namespace available only through the associated VPC resolver."
  value       = aws_route53_zone.private.name
}

output "web_service_name" {
  description = "Name of the lgm-web ECS service"
  value       = module.lgm_web.service_name
}

output "portfolio_service_name" {
  description = "Name of the portfolio ECS service"
  value       = module.portfolio.service_name
}

output "ecr_repository_url" {
  description = "ECR Image Repository URL"
  value       = module.ecr.repository_url
}

output "portfolio_ecr_repository_url" {
  description = "ECR Image Repository URL for the portfolio app"
  value       = module.ecr_portfolio.repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.ecs.cluster_arn
}

output "database_address" {
  description = "Stable private PostgreSQL hostname in the Route 53 private hosted zone."
  value       = trimsuffix(aws_route53_record.postgres.fqdn, ".")
}

output "database_rds_address" {
  description = "AWS-generated RDS endpoint hostname, retained for troubleshooting."
  value       = aws_db_instance.postgres.address
}

output "database_port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Initial PostgreSQL database name."
  value       = aws_db_instance.postgres.db_name
}

output "database_arn" {
  description = "PostgreSQL RDS instance ARN."
  value       = aws_db_instance.postgres.arn
}

output "database_subnet_ids" {
  description = "Dedicated isolated subnet IDs used by the PostgreSQL DB subnet group."
  value       = module.vpc.database_subnet_ids
}

output "netbird_routing_peer_instance_id" {
  description = "Current ASG-managed EC2 instance ID of the private NetBird routing peer."
  value       = one(data.aws_instances.netbird_routing_peer.ids)
}

output "netbird_routing_peer_private_ip" {
  description = "Current VPC-private IP address of the ASG-managed NetBird routing peer."
  value       = one(data.aws_instances.netbird_routing_peer.private_ips)
}

output "netbird_routing_peer_autoscaling_group_name" {
  description = "Fixed-size Auto Scaling Group that maintains one NetBird routing peer."
  value       = aws_autoscaling_group.netbird_routing_peer.name
}

output "netbird_routing_peer_hostname" {
  description = "Operating-system hostname registered with NetBird."
  value       = local.netbird_routing_peer_name
}

output "netbird_routed_vpc_cidr" {
  description = "CIDR to configure as the Network resource routed through the NetBird peer."
  value       = var.vpc_cidr
}

output "netbird_private_dns_match_domain" {
  description = "Match domain to configure for the NetBird DNS nameserver entry."
  value       = trimsuffix(var.private_hosted_zone_name, ".")
}

output "netbird_routing_peer_security_group_id" {
  description = "Security group allowed to administer PostgreSQL through the NetBird routing peer."
  value       = aws_security_group.netbird_routing_peer.id
}

output "netbird_routing_peer_ami_id" {
  description = "Pinned Canonical Ubuntu 26.04 LTS ARM64 AMI selected for the NetBird routing peer."
  value       = data.aws_ami.ubuntu_arm64.id
}

output "netbird_routing_peer_ami_name" {
  description = "Name of the Canonical Ubuntu AMI selected for the NetBird routing peer."
  value       = data.aws_ami.ubuntu_arm64.name
}
