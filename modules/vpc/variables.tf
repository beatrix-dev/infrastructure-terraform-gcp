variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "vpc_config" {
  description = "VPC and subnet configuration"
  type = object({
    network_name        = string
    subnet_cidr         = string
    pods_cidr           = string
    services_cidr       = string
    pods_range_name     = string
    services_range_name = string
    enable_nat          = bool
    nat_log_filter      = optional(string, "ERRORS_ONLY")
  })

  validation {
    condition     = can(cidrhost(var.vpc_config.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block (e.g. 10.0.0.0/24)"
  }

  validation {
    condition     = can(cidrhost(var.vpc_config.pods_cidr, 0))
    error_message = "pods_cidr must be a valid CIDR block (e.g. 10.1.0.0/16)"
  }

  validation {
    condition     = can(cidrhost(var.vpc_config.services_cidr, 0))
    error_message = "services_cidr must be a valid CIDR block (e.g. 10.2.0.0/20)"
  }

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL", "NONE"], var.vpc_config.nat_log_filter)
    error_message = "nat_log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY, ALL, or NONE"
  }
}

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
}

variable "subnet_labels" {
  description = "Additional labels for the GKE subnet"
  type        = map(string)
  default     = {}
}
