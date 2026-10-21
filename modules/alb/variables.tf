variable "project_name" {
  type = string

  validation {
    condition     = length(var.project_name) <= 16
    error_message = "project_name must be 16 characters or fewer so the derived target-group names stay under the 32-character AWS limit."
  }
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An ALB requires subnets in at least two Availability Zones."
  }
}

variable "certificate_arn" {
  type = string
}

variable "service_routes" {
  description = "Map of service names to domains and target-group settings"
  type = map(object({
    domains           = list(string)
    target_group_port = number
    health_check_path = string
  }))

  validation {
    condition     = length(var.service_routes) > 0
    error_message = "At least one service route must be provided."
  }
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  description = "Additional tags to apply to ALB resources."
  type        = map(string)
  default     = {}
}
