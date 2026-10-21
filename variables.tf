variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
  validation {
    condition     = contains(["prod"], var.environment)
    error_message = "Environment must be prod"
  }
}

variable "project_name" {
  type    = string
  default = "logicmatrix"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}


# ---------------------------------------------------------------------------
# Website domains
# ---------------------------------------------------------------------------

variable "service_routes" {
  description = "Map of ECS service names to domains and dedicated ALB target-group settings"
  type = map(object({
    domains           = list(string)
    target_group_port = number
    health_check_path = string
  }))

  validation {
    condition = length(var.service_routes) > 0 && alltrue([
      for service_name, route in var.service_routes :
      can(regex("^[a-z0-9-]+$", service_name)) &&
      length(route.domains) > 0 &&
      route.target_group_port >= 1 && route.target_group_port <= 65535 &&
      startswith(route.health_check_path, "/") &&
      alltrue([
        for domain in route.domains : length(trimspace(domain)) > 0 && !strcontains(domain, "/")
      ])
    ])
    error_message = "Each route needs a lowercase service key, at least one hostname, a valid port, and a health-check path beginning with /."
  }

  validation {
    condition = length(flatten([
      for route in values(var.service_routes) : route.domains
      ])) == length(distinct(flatten([
        for route in values(var.service_routes) : [for domain in route.domains : lower(trimsuffix(trimspace(domain), "."))]
    ])))
    error_message = "A domain can be assigned to only one ECS service."
  }
}

variable "lgm_service_route" {
  description = "service_routes key used by the currently deployed lgm-web ECS service"
  type        = string
  default     = "lgm-web"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags merged into every resource, on top of the provider's default_tags."
}

# ---------------------------------------------------------------------------
# Private DNS
# ---------------------------------------------------------------------------

variable "private_hosted_zone_name" {
  description = "Route 53 private hosted-zone name associated with the application VPC. This does not affect Cloudflare public DNS."
  type        = string
  default     = "aws.logicmatrix.tech"

  validation {
    condition = (
      length(trimspace(var.private_hosted_zone_name)) > 0 &&
      !strcontains(var.private_hosted_zone_name, "/") &&
      !strcontains(var.private_hosted_zone_name, " ")
    )
    error_message = "private_hosted_zone_name must be a DNS zone name without a scheme, path, or spaces."
  }
}


# Application


variable "app_container_port" {
  type    = number
  default = 3000
}

variable "app_image_tag" {
  type        = string
  default     = "latest"
  description = "ECR tag to run. Pin to an immutable tag/digest in CI so that `terraform apply` actually rolls out new code."
}

variable "app_desired_count" {
  type    = number
  default = 1
}

variable "app_cpu" {
  type        = number
  default     = 256
  description = "CPU units per task (1024 = 1 vCPU)."
}

variable "app_memory" {
  type        = number
  default     = 512
  description = "Hard memory limit in MiB per task."
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "enable_deletion_protection" {
  type        = bool
  default     = false
  description = "Set true for real production ALBs."
}

# ---------------------------------------------------------------------------
# ECS capacity
# ---------------------------------------------------------------------------

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS workers. Temporarily restricted to t4g.small."
  type        = string
  default     = "t4g.small"

  validation {
    condition     = var.ecs_instance_type == "t4g.small"
    error_message = "ecs_instance_type currently supports only t4g.small."
  }
}

variable "ecs_min_size" {
  type    = number
  default = 1
}

variable "ecs_max_size" {
  type    = number
  default = 2
}

variable "ecs_desired_capacity" {
  type    = number
  default = 1
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

variable "db_instance_type" {
  description = "RDS instance class for PostgreSQL."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL major engine version."
  type        = string
  default     = "16"
}

variable "db_port" {
  description = "PostgreSQL listener port."
  type        = number
  default     = 5432
}

variable "db_name" {
  type    = string
  default = "logicmatrix"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  description = "PostgreSQL master password. Stored in Terraform state; supply it through a secure variable source."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password must contain at least 8 characters."
  }
}

variable "db_allocated_storage" {
  description = "Initial PostgreSQL storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum PostgreSQL autoscaled storage in GiB."
  type        = number
  default     = 100
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated PostgreSQL backups."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Create a synchronous standby in another AZ. Enable for higher production availability."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protect the PostgreSQL instance from accidental deletion."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when PostgreSQL is destroyed. Keep false for production."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# NetBird database routing peer
# ---------------------------------------------------------------------------

variable "netbird_routing_peer_ami_id" {
  description = "Pinned Canonical Ubuntu 26.04 ARM64 AMI ID for the NetBird routing peer in us-east-1."
  type        = string
  default     = "ami-0b5db2dd959c9acb0"

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.netbird_routing_peer_ami_id))
    error_message = "netbird_routing_peer_ami_id must be a valid AMI ID."
  }
}

variable "netbird_routing_peer_instance_type" {
  description = "ARM64 EC2 instance type used by the private NetBird routing peer."
  type        = string
  default     = "t4g.nano"
}

variable "netbird_routing_peer_root_volume_size" {
  description = "Encrypted GP3 root volume size for the NetBird routing peer, in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.netbird_routing_peer_root_volume_size >= 8
    error_message = "netbird_routing_peer_root_volume_size must be at least 8 GiB."
  }
}

variable "netbird_routing_peer_setup_key" {
  description = "Reusable NetBird setup key stored as a write-only encrypted SSM parameter for ASG replacement instances."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.netbird_routing_peer_setup_key)) > 0
    error_message = "netbird_routing_peer_setup_key cannot be empty."
  }
}

variable "netbird_routing_peer_setup_key_version" {
  description = "Write-only SSM parameter version marker. Increment when rotating the NetBird setup key."
  type        = number
  default     = 1

  validation {
    condition     = var.netbird_routing_peer_setup_key_version >= 1 && floor(var.netbird_routing_peer_setup_key_version) == var.netbird_routing_peer_setup_key_version
    error_message = "netbird_routing_peer_setup_key_version must be a positive integer."
  }
}

variable "lgm_app_port" {
  type    = number
  default = 3000
}

variable "lgm_database_name" {
  type = string
}

variable "lgm_database_username" {
  type    = string
  default = "logicmatrixweb_admin"
}

variable "lgm_database_password" {
  type      = string
  sensitive = true
}
#.env file

variable "lgm_node_env" {
  type    = string
  default = "production"
}

variable "lgm_node_options" {
  type    = string
  default = ""
}

# variable "lgm_next_public_api_url" {
#   type = string
# }

# variable "lgm_next_public_app_url" {
#   type = string
# }

# variable "lgm_nextauth_url" {
#   type = string
# }

#variable "database_url" { type = string, sensitive = true }

variable "docker_custom_image_name" {
  type = string
}

variable "email" {
  type = string
}

variable "email_pass" {
  type      = string
  sensitive = true
}

variable "file_service_api_key" {
  type      = string
  sensitive = true
}

variable "lgm_next_public_file_service_url" {
  type = string
}

variable "lgm_next_public_file_service_user_id" {
  type = string
}

variable "lgm_next_public_ftp_dir" {
  type = string
}

variable "lgm_next_public_ftp_host" {
  type = string
}

variable "lgm_next_public_ftp_secret" {
  type      = string
  sensitive = true
}

variable "lgm_nextauth_secret" {
  type      = string
  sensitive = true
}

variable "lgm_email_server_password" {
  description = "SMTP password supplied to the LGM web application."
  type        = string
  sensitive   = true
}

variable "lgm_azure_storage_connection_string" {
  description = "Azure Storage connection string supplied to the LGM web application."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Portfolio application
# ---------------------------------------------------------------------------

variable "portfolio_service_route" {
  description = "service_routes key used by the portfolio ECS service"
  type        = string
  default     = "portfolio"
}

variable "portfolio_app_port" {
  description = "Port the portfolio Flask container listens on."
  type        = number
  default     = 5000
}

variable "portfolio_image_tag" {
  description = "ECR tag to run for the portfolio app. Pin to an immutable tag/digest in CI so that `terraform apply` actually rolls out new code."
  type        = string
  default     = "latest"
}

variable "portfolio_desired_count" {
  type    = number
  default = 1
}

variable "portfolio_cpu" {
  description = "CPU units per portfolio task (1024 = 1 vCPU)."
  type        = number
  default     = 256
}

variable "portfolio_memory" {
  description = "Hard memory limit in MiB per portfolio task."
  type        = number
  default     = 512
}

variable "portfolio_flask_app" {
  type    = string
  default = "app.py"
}

variable "portfolio_flask_env" {
  type    = string
  default = "production"
}

variable "portfolio_secret_key" {
  description = "Flask SECRET_KEY used to sign sessions."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.portfolio_secret_key)) > 0
    error_message = "portfolio_secret_key cannot be empty."
  }
}

variable "portfolio_email_host" {
  type    = string
  default = "smtp.gmail.com"
}

variable "portfolio_email_port" {
  type    = number
  default = 587
}

variable "portfolio_email_host_user" {
  type = string
}

variable "portfolio_email_host_password" {
  type      = string
  sensitive = true
}

variable "portfolio_email_use_ssl" {
  type    = bool
  default = false
}

variable "portfolio_email_use_tls" {
  type    = bool
  default = true
}

variable "portfolio_mail_default_sender" {
  type = string
}

variable "portfolio_healthcheck_max_ping_failures" {
  type    = number
  default = 5
}

variable "portfolio_database_name" {
  description = "Logical PostgreSQL database used by the portfolio app on the shared RDS instance."
  type        = string
}

variable "portfolio_database_username" {
  type    = string
  default = "mohsinrubel_admin"
}

variable "portfolio_database_password" {
  type      = string
  sensitive = true
}
