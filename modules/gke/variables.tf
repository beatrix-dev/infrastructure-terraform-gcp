variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region (regional cluster spans all zones in this region)"
  type        = string
}

variable "cluster_config" {
  description = "GKE control plane configuration"
  type = object({
    name                    = string
    release_channel         = string
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    master_ipv4_cidr_block  = string
    master_authorized_networks = list(object({
      cidr_block   = string
      display_name = string
    }))
    deletion_protection = bool
  })
}

variable "network_id" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "subnetwork_id" {
  description = "Self-link of the GKE subnet"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range used for pod IPs"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range used for service ClusterIPs"
  type        = string
}

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
}
