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
# Stage 1 (always): HA VPN gateway + Cloud Router deploy on every apply.
#                   Outputs vpn_gateway_ips — give these to the remote peer.
# Stage 2 (peer IPs set): tunnels, BGP sessions, and firewall rule activate.
# ---------------------------------------------------------------------------
variable "vpn_peer_tunnel_ips" {
  description = "4 outside IPs of the remote peer. Leave empty for stage-1 (gateway only). Set all 4 to activate tunnels."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.vpn_peer_tunnel_ips) == 0 || length(var.vpn_peer_tunnel_ips) == 4
    error_message = "vpn_peer_tunnel_ips must be empty (stage-1) or contain exactly 4 IPs (stage-2)."
  }
}

variable "vpn_peer_cidr" {
  description = "CIDR of the remote network — required for stage-2 (when vpn_peer_tunnel_ips is set)"
  type        = string
  default     = null
}

variable "vpn_peer_asn" {
  description = "BGP ASN of the remote peer"
  type        = number
  default     = 64512
}

variable "vpn_shared_secret" {
  description = "Pre-shared key for all VPN tunnels — required for stage-2"
  type        = string
  sensitive   = true
  default     = null
}

