variable "project_name" {
  description = "Name of the overall project."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Optional ECS cluster name. Defaults to <project_name>-<environment>-ecs-cluster."
  type        = string
  default     = null
}

variable "capacity_provider_name" {
  description = "Optional name for the ECS capacity provider. Defaults to <cluster_name>-capacity-provider."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the ECS cluster and related resources."
  type        = map(string)
  default     = {}
}

variable "capacity_providers" {
  description = "Capacity providers to associate with the ECS cluster for EC2-backed workloads."
  type        = list(string)
  default     = []
}

variable "default_capacity_provider" {
  description = "Default capacity provider to use for the ECS cluster."
  type        = string
  default     = null
}

variable "default_capacity_provider_weight" {
  description = "Weight for the default capacity provider strategy."
  type        = number
  default     = 100
}

variable "default_capacity_provider_base" {
  description = "Base value for the default capacity provider strategy."
  type        = number
  default     = 1
}

variable "container_insights_enabled" {
  description = "Enable CloudWatch Container Insights for the ECS cluster."
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS workers. Temporarily restricted to t4g.small."
  type        = string
  default     = "t4g.small"

  validation {
    condition     = var.ec2_instance_type == "t4g.small"
    error_message = "ec2_instance_type currently supports only t4g.small."
  }
}

variable "vpc_id" {
  description = "VPC ID where ECS instances and security groups will be created."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB, used by ECS task security groups."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for ECS EC2 instances."
  type        = list(string)
}

variable "min_capacity" {
  description = "Minimum size for the ECS autoscaling group."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum size for the ECS autoscaling group."
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired size for the ECS autoscaling group."
  type        = number
  default     = 1
}

variable "asg_tags" {
  description = "Additional tags to apply to ECS Auto Scaling Group instances."
  type        = map(string)
  default     = {}
}

variable "web_port" {
  description = "Port used by web ECS tasks."
  type        = number
  default     = 8080
}

variable "api_port" {
  description = "Port used by API ECS tasks."
  type        = number
  default     = 8080
}

variable "sftp_enabled" {
  description = "Enable SFTP egress for API ECS tasks."
  type        = bool
  default     = false
}

variable "sftp_port" {
  description = "SFTP port to allow for API ECS tasks when enabled."
  type        = number
  default     = 22
}

variable "mongodb_atlas_cidr_block" {
  description = "CIDR block used to allow MongoDB Atlas traffic to API ECS tasks."
  type        = string
  default     = ""
}
