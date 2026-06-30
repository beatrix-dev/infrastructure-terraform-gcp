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
# VPN / AWS connectivity
# ---------------------------------------------------------------------------
variable "enable_vpn" {
  description = "Set to true to deploy the GCP HA VPN and all AWS-side resources"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region where VPN resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "aws_vpc_id" {
  description = "AWS VPC ID to connect to via Site-to-Site VPN (required when enable_vpn = true)"
  type        = string
  default     = null
}

variable "aws_vpc_cidr" {
  description = "CIDR block of the AWS VPC — must not overlap with GCP ranges 10.0/24, 10.1/16, 10.2/20 (required when enable_vpn = true)"
  type        = string
  default     = null
}

variable "aws_route_table_ids" {
  description = "AWS route table IDs to enable VPN route propagation into (typically your private subnets)"
  type        = list(string)
  default     = []
}

variable "vpn_shared_secret" {
  description = "Pre-shared key for all four VPN tunnels (required when enable_vpn = true)"
  type        = string
  sensitive   = true
  default     = null
}




