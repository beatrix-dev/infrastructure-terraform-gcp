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
  description = "BGP ASN of the remote peer (e.g. 64512 for AWS VGW, or your on-prem ASN)"
  type        = number
  default     = 64512
}

variable "peer_tunnel_ips" {
  description = <<-EOT
    List of exactly 4 outside IP addresses of the remote VPN peer tunnels.
    Mapping:
      [0] → GCP interface 0, peer interface 0
      [1] → GCP interface 1, peer interface 1
      [2] → GCP interface 0, peer interface 2
      [3] → GCP interface 1, peer interface 3
  EOT
  type        = list(string)

  validation {
    condition     = length(var.peer_tunnel_ips) == 4
    error_message = "peer_tunnel_ips must contain exactly 4 IP addresses."
  }
}

variable "peer_cidr" {
  description = "CIDR block of the remote network — used to allow inbound traffic through the GCP firewall"
  type        = string

  validation {
    condition     = can(cidrhost(var.peer_cidr, 0))
    error_message = "peer_cidr must be a valid CIDR block (e.g. 10.10.0.0/16)"
  }
}

variable "shared_secret" {
  description = "Pre-shared key for all VPN tunnels — must match what is configured on the remote peer"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels applied to all GCP resources"
  type        = map(string)
  default     = {}
}
