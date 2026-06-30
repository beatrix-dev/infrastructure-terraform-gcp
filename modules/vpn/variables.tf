variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "network_id" {
  description = "Self-link of the GCP VPC network"
  type        = string
}

variable "network_name" {
  description = "Name of the GCP VPC network (used for firewall rules)"
  type        = string
}

variable "gcp_asn" {
  description = "BGP ASN for the GCP Cloud Router"
  type        = number
  default     = 65000
}

variable "aws_asn" {
  description = "BGP ASN for the AWS Virtual Private Gateway"
  type        = number
  default     = 64512
}

variable "aws_vpc_id" {
  description = "AWS VPC ID to attach the Virtual Private Gateway"
  type        = string
}

variable "aws_vpc_cidr" {
  description = "CIDR block of the AWS VPC (used to allow inbound traffic on GCP firewall)"
  type        = string

  validation {
    condition     = can(cidrhost(var.aws_vpc_cidr, 0))
    error_message = "aws_vpc_cidr must be a valid CIDR block (e.g. 10.10.0.0/16)"
  }
}

variable "aws_route_table_ids" {
  description = "AWS route table IDs to enable VPN route propagation into"
  type        = list(string)
  default     = []
}

variable "shared_secret" {
  description = "Pre-shared key for all VPN tunnels"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels applied to GCP resources"
  type        = map(string)
  default     = {}
}
