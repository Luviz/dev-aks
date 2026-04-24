variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  # TODO: Set your project name
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
