variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region where the VPN gateway and tunnels are deployed"
  type        = string
}

variable "network_id" {
  description = "Self-link of the GCP VPC network"
  type        = string
}

variable "network_name" {
  description = "Name of the GCP VPC network (used for the firewall rule)"
  type        = string
}

variable "gcp_asn" {
  description = "BGP ASN for the GCP Cloud Router"
  type        = number
  default     = 65000
}

variable "peer_asn" {
  description = "BGP ASN of the remote peer (AWS default is 64512)"
  type        = number
  default     = 64512
}

# ---------------------------------------------------------------------------
# Routing mode — must match what each AWS VPN connection was created with.
# AWS VPN connections are all-static or all-dynamic; there's no per-tunnel
# mixing. If AWS was set up as "Static", set this to "STATIC" too.
# ---------------------------------------------------------------------------
variable "routing_mode" {
  description = "\"DYNAMIC\" for BGP-based routing (needs bgp_tunnelN_cidr/peer_ip vars) or \"STATIC\" for static routes (needs static_route_destination_ranges). Must match what the AWS VPN connections use."
  type        = string
  default     = "STATIC"

  validation {
    condition     = contains(["DYNAMIC", "STATIC"], var.routing_mode)
    error_message = "routing_mode must be DYNAMIC or STATIC."
  }
}

variable "static_route_destination_ranges" {
  description = "Destination CIDR(s) to route over the tunnels when routing_mode = \"STATIC\" (one google_compute_route per tunnel per CIDR). Defaults to [peer_cidr] when left empty — set explicitly for a narrower/different range."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.static_route_destination_ranges : can(cidrhost(c, 0))])
    error_message = "static_route_destination_ranges must contain valid CIDR blocks."
  }
}

variable "static_route_priority" {
  description = "Priority applied to every static route (routing_mode = \"STATIC\"). Kept equal across all 4 tunnels for ECMP-style failover — lower number wins if you deliberately want a primary/backup split instead."
  type        = number
  default     = 1000
}

# ---------------------------------------------------------------------------
# Stage-2 variables — populate from the two AWS VPN connections' details.
#
# This deploys 4 tunnels (FOUR_IPS_REDUNDANCY): AWS exposes 2 separate
# Site-to-Site VPN connections, each with 2 tunnels, both connections
# pointing at the SAME GCP HA VPN gateway (one connection per GCP interface):
#   - AWS VPN connection #1 (Customer Gateway = GCP interface 0 IP) -> tunnel 0, tunnel 1
#   - AWS VPN connection #2 (Customer Gateway = GCP interface 1 IP) -> tunnel 2, tunnel 3
# ---------------------------------------------------------------------------

variable "peer_tunnel_ips" {
  description = <<-EOT
    4 outside IPs from AWS, one per tunnel, in this exact order:
      [0] AWS VPN connection #1, Tunnel 1 outside IP (Virtual Private Gateway)
      [1] AWS VPN connection #1, Tunnel 2 outside IP (Virtual Private Gateway)
      [2] AWS VPN connection #2, Tunnel 1 outside IP (Virtual Private Gateway)
      [3] AWS VPN connection #2, Tunnel 2 outside IP (Virtual Private Gateway)
    Indexes 0-1 terminate on GCP HA VPN interface 0; indexes 2-3 terminate on
    GCP HA VPN interface 1. Leave empty for stage-1 (gateway/router only).
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.peer_tunnel_ips) == 0 || length(var.peer_tunnel_ips) == 4
    error_message = "peer_tunnel_ips must be empty (stage-1) or contain exactly 4 IPs (stage-2, 2 AWS VPN connections x 2 tunnels)."
  }
}

variable "tunnel0_psk" {
  description = "Pre-shared key for tunnel 0 — from AWS VPN connection #1, Tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "tunnel1_psk" {
  description = "Pre-shared key for tunnel 1 — from AWS VPN connection #1, Tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "tunnel2_psk" {
  description = "Pre-shared key for tunnel 2 — from AWS VPN connection #2, Tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "tunnel3_psk" {
  description = "Pre-shared key for tunnel 3 — from AWS VPN connection #2, Tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

# Only used when routing_mode = "DYNAMIC". AWS assigns the BGP inside CIDRs.
# Get these from each AWS VPN connection's "Tunnel Details" tab, under
# "Inside IP addresses". Each tunnel has two addresses on the same /30 link:
#   - "Customer Gateway"        -> the GCP side  -> use in *_cidr (below)
#   - "Virtual Private Gateway" -> the AWS side   -> use in *_peer_ip (below)

variable "bgp_tunnel0_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 0 — AWS conn #1 tunnel 1, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.235.137/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel1_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 1 — AWS conn #1 tunnel 2, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.37.197/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel2_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 2 — AWS conn #2 tunnel 1, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.96.42/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel3_cidr" {
  description = "GCP-side BGP inside IP with /30 for tunnel 3 — AWS conn #2 tunnel 2, 'Inside IP addresses > Customer Gateway' (e.g. 169.254.89.254/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel0_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 0 — AWS conn #1 tunnel 1, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.235.138)"
  type        = string
  default     = null
}

variable "bgp_tunnel1_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 1 — AWS conn #1 tunnel 2, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.37.198)"
  type        = string
  default     = null
}

variable "bgp_tunnel2_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 2 — AWS conn #2 tunnel 1, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.96.41)"
  type        = string
  default     = null
}

variable "bgp_tunnel3_peer_ip" {
  description = "AWS-side BGP inside IP for tunnel 3 — AWS conn #2 tunnel 2, 'Inside IP addresses > Virtual Private Gateway' (e.g. 169.254.89.253)"
  type        = string
  default     = null
}

variable "peer_cidr" {
  description = "AWS VPC CIDR block — used to create an inbound firewall rule"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to all GCP resources"
  type        = map(string)
  default     = {}
}
