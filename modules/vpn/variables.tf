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
  description = "Self-link of the GCP VPC network to attach the VPN gateway to"
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
  description = "BGP ASN of the remote peer"
  type        = number
  default     = 64512
}

variable "peer_tunnel_ips" {
  description = "4 outside IPs of the remote peer. Empty = stage-1 (gateway only). 4 IPs = stage-2 (tunnels active)."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.peer_tunnel_ips) == 0 || length(var.peer_tunnel_ips) == 4
    error_message = "peer_tunnel_ips must be empty or contain exactly 4 IPs."
  }
}

variable "peer_cidr" {
  description = "CIDR block of the remote network — used for the inbound firewall rule (stage-2)"
  type        = string
  default     = null
}

variable "shared_secret" {
  description = "Pre-shared key for all VPN tunnels (stage-2)"
  type        = string
  sensitive   = true
  default     = null
}

variable "labels" {
  description = "Labels applied to all GCP resources"
  type        = map(string)
  default     = {}
}
