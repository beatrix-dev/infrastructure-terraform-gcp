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

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "dev"
}

variable "gcp_location" {
  description = "GCP location for resources (region or zone)"
  type        = string
  default     = "us-central1"
}

variable "node_service_account_email" {
  description = "Service account email for GKE node pools"
  type        = string
  default     = null
}



# ---------------------------------------------------------------------------
# Cloud VPN (HA VPN — either topology, chosen dynamically by how many peer
# tunnel IPs are supplied):
#
#   - 1 peer IP  : a single peer device (e.g. FortiGate or other on-prem VPN
#                  appliance) — 1 tunnel, terminated on GCP interface 0 only.
#                  99.9% SLA (same as classic VPN; no interface-level failover).
#   - 4 peer IPs : AWS Site-to-Site VPN, FOUR_IPS_REDUNDANCY — 2 AWS VPN
#                  connections x 2 tunnels each, both pointing at this same
#                  GCP HA VPN gateway. 99.99% SLA.
#
# Stage 1 (always): HA VPN gateway + Cloud Router deploy on every apply.
#                   Outputs vpn_gateway_ip_0 (and, for the 4-tunnel AWS case,
#                   vpn_gateway_ip_1 too) — give these to the peer when
#                   configuring its side of the tunnel(s).
# Stage 2 (peer IPs set): external gateway, tunnels, BGP sessions, and firewall activate.
#
# AWS side: 2 separate Site-to-Site VPN connections, 2 tunnels each:
#   - AWS VPN connection #1 (Customer Gateway = vpn_gateway_ip_0) -> tunnel 0, tunnel 1
#   - AWS VPN connection #2 (Customer Gateway = vpn_gateway_ip_1) -> tunnel 2, tunnel 3
#
# Routing mode must match what the peer side was created with (AWS is
# all-static or all-dynamic per connection, no per-tunnel mixing; a single
# device like a FortiGate is whatever you configure on it).
# ---------------------------------------------------------------------------
variable "vpn_routing_mode" {
  description = "\"DYNAMIC\" for BGP-based routing or \"STATIC\" for static routes — must match the peer's routing option"
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
  description = "Priority applied to every static route (vpn_routing_mode = \"STATIC\") — equal across tunnels for ECMP-style failover"
  type        = number
  default     = 1000
}

variable "vpn_peer_tunnel_ips" {
  description = <<-EOT
    Outside tunnel IP(s) from the peer, one per tunnel:
      - 1 IP  : single peer device (e.g. FortiGate) — terminates on GCP interface 0.
      - 4 IPs : AWS Site-to-Site VPN, in this exact order:
          [0] AWS VPN connection #1, Tunnel 1 outside IP (Virtual Private Gateway)
          [1] AWS VPN connection #1, Tunnel 2 outside IP (Virtual Private Gateway)
          [2] AWS VPN connection #2, Tunnel 1 outside IP (Virtual Private Gateway)
          [3] AWS VPN connection #2, Tunnel 2 outside IP (Virtual Private Gateway)
    Leave empty for stage-1.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = contains([0, 1, 4], length(var.vpn_peer_tunnel_ips))
    error_message = "vpn_peer_tunnel_ips must be empty (stage-1), exactly 1 IP (stage-2, single peer device), or exactly 4 IPs (stage-2, AWS: 2 VPN connections x 2 tunnels)."
  }
}

variable "vpn_peer_cidr" {
  description = "Peer network CIDR block (AWS VPC CIDR, or the FortiGate/on-prem LAN CIDR) — used to create firewall rules (stage-2)"
  type        = string
  default     = null
}

variable "vpn_peer_asn" {
  description = "BGP ASN of the peer (AWS VGW default is 64512; check your device's config for a single-peer-device setup)"
  type        = number
  default     = 64512
}

variable "vpn_tunnel_psks" {
  description = "Pre-shared key(s), one per tunnel, in the same order as vpn_peer_tunnel_ips (1 entry for a single-device peer, 4 for AWS) — set as a sensitive Terraform variable in TFC"
  type        = list(string)
  sensitive   = true
  default     = []
}

# The peer assigns BGP inside CIDRs — for AWS, copy from each VPN
# connection's Tunnel details > Inside IP addresses. Each tunnel has two
# addresses on one /30:
#   - "Customer Gateway"        -> the GCP side  -> vpn_bgp_tunnel_cidrs
#   - "Virtual Private Gateway" -> the peer side -> vpn_bgp_tunnel_peer_ips
# For a single device like a FortiGate, use whatever /30 you configure on its
# VPN interface for the GCP side, and its own tunnel-interface IP as the peer IP.
variable "vpn_bgp_tunnel_cidrs" {
  description = "GCP-side BGP inside IP with /30, one per tunnel, in the same order as vpn_peer_tunnel_ips (e.g. 169.254.235.137/30)"
  type        = list(string)
  default     = []
}

variable "vpn_bgp_tunnel_peer_ips" {
  description = "Peer-side BGP inside IP, one per tunnel, in the same order as vpn_peer_tunnel_ips (e.g. 169.254.235.138)"
  type        = list(string)
  default     = []
}

