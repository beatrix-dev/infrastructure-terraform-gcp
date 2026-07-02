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
# Cloud VPN (HA VPN — AWS Site-to-Site, 4-tunnel / FOUR_IPS_REDUNDANCY)
# Stage 1 (always): HA VPN gateway + Cloud Router deploy on every apply.
#                   Outputs vpn_gateway_ip_0 / vpn_gateway_ip_1 — give these to
#                   AWS as the two Customer Gateway IPs when creating the two
#                   AWS VPN connections (one connection per GCP interface).
# Stage 2 (peer IPs set): external gateway, tunnels, BGP sessions, and firewall activate.
#
# AWS side: 2 separate Site-to-Site VPN connections, 2 tunnels each:
#   - AWS VPN connection #1 (Customer Gateway = vpn_gateway_ip_0) -> tunnel 0, tunnel 1
#   - AWS VPN connection #2 (Customer Gateway = vpn_gateway_ip_1) -> tunnel 2, tunnel 3
#
# All stage-2 values come from each AWS VPN connection's detail page.
#
# Routing mode must match what each AWS VPN connection was created with
# (AWS is all-static or all-dynamic per connection, no per-tunnel mixing).
# ---------------------------------------------------------------------------
variable "vpn_routing_mode" {
  description = "\"DYNAMIC\" for BGP-based routing or \"STATIC\" for static routes — must match the AWS VPN connections' routing option"
  type        = string
  default     = "STATIC"

  validation {
    condition     = contains(["DYNAMIC", "STATIC"], var.vpn_routing_mode)
    error_message = "vpn_routing_mode must be DYNAMIC or STATIC."
  }
}

variable "vpn_static_route_destination_ranges" {
  description = "Destination CIDR(s) routed over the tunnels when vpn_routing_mode = \"STATIC\". Defaults to [vpn_peer_cidr] when left empty."
  type        = list(string)
  default     = []
}

variable "vpn_static_route_priority" {
  description = "Priority applied to all 4 static routes (vpn_routing_mode = \"STATIC\") — equal across tunnels for ECMP-style failover"
  type        = number
  default     = 1000
}

variable "vpn_peer_tunnel_ips" {
  description = <<-EOT
    4 outside IPs from AWS, one per tunnel, in this exact order:
      [0] AWS VPN connection #1, Tunnel 1 outside IP (Virtual Private Gateway)
      [1] AWS VPN connection #1, Tunnel 2 outside IP (Virtual Private Gateway)
      [2] AWS VPN connection #2, Tunnel 1 outside IP (Virtual Private Gateway)
      [3] AWS VPN connection #2, Tunnel 2 outside IP (Virtual Private Gateway)
    Leave empty for stage-1.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.vpn_peer_tunnel_ips) == 0 || length(var.vpn_peer_tunnel_ips) == 4
    error_message = "vpn_peer_tunnel_ips must be empty (stage-1) or contain exactly 4 IPs (stage-2, 2 AWS VPN connections x 2 tunnels)."
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

# Each AWS tunnel has its own PSK — set all four as sensitive Terraform variables in TFC
variable "vpn_tunnel0_psk" {
  description = "Pre-shared key for tunnel 0 — from AWS VPN connection #1, Tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpn_tunnel1_psk" {
  description = "Pre-shared key for tunnel 1 — from AWS VPN connection #1, Tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpn_tunnel2_psk" {
  description = "Pre-shared key for tunnel 2 — from AWS VPN connection #2, Tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpn_tunnel3_psk" {
  description = "Pre-shared key for tunnel 3 — from AWS VPN connection #2, Tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

# AWS assigns BGP inside CIDRs — copy from each AWS VPN connection's Tunnel
# details > Inside IP addresses. Each tunnel has two addresses on one /30:
#   - "Customer Gateway"        -> the GCP side  -> *_cidr variables below
#   - "Virtual Private Gateway" -> the AWS side   -> *_peer_ip variables below
variable "vpn_bgp_tunnel0_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 0 — AWS conn #1 tunnel 1, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.235.137/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel1_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 1 — AWS conn #1 tunnel 2, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.37.197/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel2_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 2 — AWS conn #2 tunnel 1, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.96.42/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel3_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 3 — AWS conn #2 tunnel 2, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.89.254/30)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel0_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 0 — AWS conn #1 tunnel 1, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.235.138)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel1_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 1 — AWS conn #1 tunnel 2, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.37.198)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel2_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 2 — AWS conn #2 tunnel 1, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.96.41)"
  type        = string
  default     = null
}

variable "vpn_bgp_tunnel3_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 3 — AWS conn #2 tunnel 2, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.89.253)"
  type        = string
  default     = null
}

