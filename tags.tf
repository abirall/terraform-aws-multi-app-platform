locals {
  global_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Team        = "DevOps"
  }
}