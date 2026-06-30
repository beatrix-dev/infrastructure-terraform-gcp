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
    condition     = can(regex("^(us|europe|asia|northamerica|southamerica|australia)-[a-z]+-[0-9]+[a-f]$", var.zone))
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




