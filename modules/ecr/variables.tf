variable "project_name" {
  type = string
}

variable "repo_name" {
  description = "Optional explicit repository name. Defaults to \"<project_name>-repo\"."
  type        = string
  default     = null
}
