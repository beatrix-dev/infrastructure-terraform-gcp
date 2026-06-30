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
# Stage-2 variables — populate from the AWS VPN connection details
# ---------------------------------------------------------------------------

variable "peer_tunnel_ips" {
  description = "2 outside IPs from the AWS VPN connection. Empty = stage-1 (gateway only). 2 IPs = stage-2 (tunnels active)."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.peer_tunnel_ips) == 0 || length(var.peer_tunnel_ips) == 2
    error_message = "peer_tunnel_ips must be empty (stage-1) or contain exactly 2 IPs (stage-2)."
  }
}

variable "tunnel0_psk" {
  description = "Pre-shared key for tunnel 0 — from AWS VPN connection tunnel 1 details"
  type        = string
  sensitive   = true
  default     = null
}

variable "tunnel1_psk" {
  description = "Pre-shared key for tunnel 1 — from AWS VPN connection tunnel 2 details"
  type        = string
  sensitive   = true
  default     = null
}

# AWS assigns the BGP inside CIDRs. Get these from the AWS VPN connection detail page.
variable "bgp_tunnel0_cidr" {
  description = "GCP-side BGP /30 CIDR for tunnel 0 — 'Inside IP addresses > Customer gateway' from AWS (e.g. 169.254.235.137/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel1_cidr" {
  description = "GCP-side BGP /30 CIDR for tunnel 1 — 'Inside IP addresses > Customer gateway' from AWS (e.g. 169.254.37.197/30)"
  type        = string
  default     = null
}

variable "bgp_tunnel0_peer_ip" {
  description = "AWS-side BGP peer IP for tunnel 0 — 'Inside IP addresses > Virtual private gateway' from AWS (e.g. 169.254.235.138)"
  type        = string
  default     = null
}

variable "bgp_tunnel1_peer_ip" {
  description = "AWS-side BGP peer IP for tunnel 1 — 'Inside IP addresses > Virtual private gateway' from AWS (e.g. 169.254.37.198)"
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
