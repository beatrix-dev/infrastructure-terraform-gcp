variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region — node pools are spread across all zones in this region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster this node pool belongs to"
  type        = string
}

variable "node_service_account_email" {
  description = "Email of the GCP service account used by all node VMs"
  type        = string
}

variable "node_pools" {
  description = "Map of GKE node pool configurations"
  type = map(object({
    machine_type       = string
    disk_size_gb       = number
    disk_type          = string
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number
    spot               = bool
    labels             = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
    oauth_scopes = list(string)
    accelerator = optional(object({
      type               = string
      count              = number
      gpu_driver_version = optional(string, "DEFAULT")
    }))
  }))

  validation {
    condition     = alltrue([for pool in var.node_pools : pool.disk_size_gb >= 10])
    error_message = "disk_size_gb must be at least 10 for all node pools"
  }

  validation {
    condition     = alltrue([for pool in var.node_pools : pool.min_node_count <= pool.max_node_count])
    error_message = "min_node_count must be <= max_node_count for all node pools"
  }

  validation {
    condition     = alltrue([for pool in var.node_pools : pool.initial_node_count >= pool.min_node_count])
    error_message = "initial_node_count must be >= min_node_count for all node pools"
  }

  validation {
    condition     = alltrue([for pool in var.node_pools : contains(["pd-standard", "pd-ssd", "pd-balanced", "pd-extreme"], pool.disk_type)])
    error_message = "disk_type must be pd-standard, pd-ssd, pd-balanced, or pd-extreme for all node pools"
  }

  validation {
    condition = alltrue(flatten([
      for pool in var.node_pools : [
        for taint in pool.taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], taint.effect)
      ]
    ]))
    error_message = "taint effect must be NO_SCHEDULE, PREFER_NO_SCHEDULE, or NO_EXECUTE"
  }
}

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
}
