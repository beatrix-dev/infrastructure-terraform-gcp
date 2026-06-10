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
}

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
}
