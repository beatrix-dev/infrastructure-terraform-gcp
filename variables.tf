variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "dev-cluster"
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^(us|europe|asia|northamerica|southamerica|australia)-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a valid GCP region (e.g. us-central1, europe-west1)"
  }
}

variable "zone" {
  description = "GCP zone for the cluster"
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = can(regex("^(us|europe|asia|northamerica|southamerica|australia)-[a-z]+[0-9]+-[a-f]$", var.zone))
    error_message = "zone must be a valid GCP zone (e.g. us-central1-a)"
  }
}

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
  default     = {}
}

variable "repository_id" {
  description = "Artifact Registry repository ID for the container registry in gcp"
  type        = string
  default     = "app-images"
}

# ---------------------------------------------------------------------------
# Cloud VPN (HA VPN)
# ---------------------------------------------------------------------------
variable "enable_vpn" {
  description = "Set to true to deploy GCP Cloud VPN resources"
  type        = bool
  default     = false
}

variable "vpn_peer_tunnel_ips" {
  description = "4 outside IP addresses of the remote VPN peer (from AWS, on-prem, or another cloud)"
  type        = list(string)
  default     = []
}

variable "vpn_peer_cidr" {
  description = "CIDR of the remote network reachable over the VPN"
  type        = string
  default     = null
}

variable "vpn_peer_asn" {
  description = "BGP ASN of the remote peer"
  type        = number
  default     = 64512
}

variable "vpn_shared_secret" {
  description = "Pre-shared key for all VPN tunnels"
  type        = string
  sensitive   = true
  default     = null
}

