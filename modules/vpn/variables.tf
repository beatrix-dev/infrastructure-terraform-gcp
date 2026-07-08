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
  description = "BGP ASN of the remote peer (AWS default is 64512; check your device's config for a single-peer-device setup like FortiGate)"
  type        = number
  default     = 64512
}

# ---------------------------------------------------------------------------
# Routing mode — must match what the peer side was created with.
# AWS VPN connections are all-static or all-dynamic; there's no per-tunnel
# mixing. If AWS (or your FortiGate/other device) was set up as "Static",
# set this to "STATIC" too.
# ---------------------------------------------------------------------------
variable "routing_mode" {
  description = "\"DYNAMIC\" for BGP-based routing (needs bgp_tunnel_cidrs/bgp_tunnel_peer_ips) or \"STATIC\" for static routes (needs static_route_destination_ranges). Must match what the peer device/connections use."
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
  description = "Priority applied to every static route (routing_mode = \"STATIC\"). Kept equal across all tunnels for ECMP-style failover — lower number wins if you deliberately want a primary/backup split instead."
  type        = number
  default     = 1000
}

# ---------------------------------------------------------------------------
# Stage-2 variables — populate once the peer side is known. Either shape works:
#
#   - 1 IP  : a single peer device (e.g. a FortiGate or other on-prem VPN
#             appliance). One tunnel, terminated on GCP HA VPN interface 0.
#             Gets 99.9% SLA (same as classic VPN) — no interface-level
#             failover, since interface 1 goes unused.
#
#   - 4 IPs : AWS Site-to-Site VPN. AWS always creates 2 tunnels per VPN
#             connection, so full 99.99% HA VPN redundancy needs 2 AWS VPN
#             connections, both pointing at this same GCP gateway (one
#             connection per GCP interface):
#               - AWS VPN connection #1 (Customer Gateway = interface 0 IP) -> tunnel 0, tunnel 1
#               - AWS VPN connection #2 (Customer Gateway = interface 1 IP) -> tunnel 2, tunnel 3
# ---------------------------------------------------------------------------

variable "peer_tunnel_ips" {
  description = <<-EOT
    Outside tunnel IP(s) from the peer, one per tunnel:
      - 1 IP  : single peer device (e.g. FortiGate) — terminates on GCP interface 0.
      - 4 IPs : AWS Site-to-Site VPN, in this exact order:
          [0] AWS VPN connection #1, Tunnel 1 outside IP (Virtual Private Gateway)
          [1] AWS VPN connection #1, Tunnel 2 outside IP (Virtual Private Gateway)
          [2] AWS VPN connection #2, Tunnel 1 outside IP (Virtual Private Gateway)
          [3] AWS VPN connection #2, Tunnel 2 outside IP (Virtual Private Gateway)
        Indexes 0-1 terminate on GCP HA VPN interface 0; indexes 2-3 terminate on
        GCP HA VPN interface 1.
    Leave empty for stage-1 (gateway/router only).
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = contains([0, 1, 4], length(var.peer_tunnel_ips))
    error_message = "peer_tunnel_ips must be empty (stage-1), contain exactly 1 IP (stage-2, single peer device), or exactly 4 IPs (stage-2, AWS: 2 VPN connections x 2 tunnels)."
  }
}

variable "tunnel_psks" {
  description = "Pre-shared key(s), one per tunnel, in the same order as peer_tunnel_ips (1 entry for a single-device peer, 4 for AWS)"
  type        = list(string)
  sensitive   = true
  default     = []
}

# Only used when routing_mode = "DYNAMIC". The peer assigns the BGP inside
# CIDRs — for AWS, get these from each VPN connection's "Tunnel Details" tab,
# under "Inside IP addresses" (each tunnel has two addresses on the same /30):
#   - "Customer Gateway"        -> the GCP side  -> use in bgp_tunnel_cidrs
#   - "Virtual Private Gateway" -> the peer side -> use in bgp_tunnel_peer_ips
# For a single device like a FortiGate, use whatever /30 you configure on
# its VPN interface for the GCP side, and its own tunnel-interface IP as the peer IP.

variable "bgp_tunnel_cidrs" {
  description = "GCP-side BGP inside IP with /30, one per tunnel, in the same order as peer_tunnel_ips (e.g. 169.254.235.137/30)"
  type        = list(string)
  default     = []
}

variable "bgp_tunnel_peer_ips" {
  description = "Peer-side BGP inside IP, one per tunnel, in the same order as peer_tunnel_ips (e.g. 169.254.235.138)"
  type        = list(string)
  default     = []
}

variable "peer_cidr" {
  description = "Peer network CIDR block (AWS VPC CIDR, or the FortiGate/on-prem LAN CIDR) — used to create firewall rules"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to all GCP resources"
  type        = map(string)
  default     = {}
}
