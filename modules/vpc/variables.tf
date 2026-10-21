variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 4, 4))
    error_message = "vpc_cidr must be a CIDR block with room for at least five /4-offset subnets (e.g. 10.0.0.0/16)."
  }
}
