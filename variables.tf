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
# Cloud VPN (HA VPN — AWS Site-to-Site)
# Stage 1 (always): HA VPN gateway + Cloud Router deploy on every apply.
#                   Outputs vpn_gateway_ips — give these to AWS when creating the VGW.
# Stage 2 (peer IPs set): external gateway, tunnels, BGP sessions, and firewall activate.
#
# All stage-2 values come from the AWS VPN connection detail page.
# ---------------------------------------------------------------------------
variable "vpn_peer_tunnel_ips" {
  description = "2 outside IPs from the AWS VPN connection (tunnel 1 and tunnel 2 outside IPs). Leave empty for stage-1."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.vpn_peer_tunnel_ips) == 0 || length(var.vpn_peer_tunnel_ips) == 2
    error_message = "vpn_peer_tunnel_ips must be empty (stage-1) or contain exactly 2 IPs (stage-2)."
  }
}

variable "vpn_peer_cidr" {
  description = "AWS VPC CIDR block — used to create an inbound firewall rule (stage-2)"
  type        = string
  default     = null
}

variable "vpn_peer_asn" {
  description = "BGP ASN of the AWS VGW (default 64512)"
  type        = number
  default     = 64512
}

# Each AWS tunnel has its own PSK — set both as sensitive Terraform variables in TFC
variable "vpn_tunnel0_psk" {
  description = "Pre-shared key for tunnel 0 — from AWS VPN connection > Tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpn_tunnel1_psk" {
  description = "Pre-shared key for tunnel 1 — from AWS VPN connection > Tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

# AWS assigns BGP inside CIDRs — copy from AWS VPN connection > Tunnel details > Inside IP addresses
variable "vpn_bgp_tunnel0_cidr" {
  description = "GCP-side BGP /30 CIDR for tunnel 0 (Customer gateway inside IP with /30, e.g. 169.254.235.137/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel1_cidr" {
  description = "GCP-side BGP /30 CIDR for tunnel 1 (Customer gateway inside IP with /30, e.g. 169.254.37.197/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel0_peer_ip" {
  description = "AWS-side BGP peer IP for tunnel 0 (Virtual private gateway inside IP, e.g. 169.254.235.138)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel1_peer_ip" {
  description = "AWS-side BGP peer IP for tunnel 1 (Virtual private gateway inside IP, e.g. 169.254.37.198)"
  type        = string
  default     = null
}

