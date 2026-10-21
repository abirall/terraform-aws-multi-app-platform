variable "project_name" {
  description = "Name of the project for naming ECS resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for ECS logs and IAM roles."
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Optional ECS service name."
  type        = string
  default     = null
}

variable "task_family" {
  description = "Optional ECS task definition family name."
  type        = string
  default     = null
}

variable "container_name" {
  description = "Container name used in the task definition."
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Container image for the ECS task."
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 5000
}

variable "cpu" {
  description = "CPU units reserved for the container."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MiB) reserved for the container."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "cluster_name" {
  description = "ECS cluster name for the service."
  type        = string
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group used by the ECS service."
  type        = string
}

variable "task_role_arn" {
  description = "Optional IAM role ARN to attach to the ECS task."
  type        = string
  default     = null
}

variable "container_environment" {
  description = "Environment variables passed to the container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets exposed to the container as ECS secrets."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the container logs."
  type        = number
  default     = 30
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent for ECS service deployment."
  type        = number
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum percent for ECS service deployment."
  type        = number
  default     = 200
}

variable "health_check_grace_period_seconds" {
  description = "Health check grace period for ECS service deployments."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Additional tags to apply to ECS resources."
  type        = map(string)
  default     = {}
}
