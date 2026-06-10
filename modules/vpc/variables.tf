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
