variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Location of the Container Registry"
  type        = string
}

variable "repository_id" {
  description = "ID of the Container Registry repository"
  type        = string
}

variable "description" {
  description = "Description of the Container Registry repository"
  type        = string
  default     = ""
}

variable "format" {
  description = "Format of the Container Registry (e.g., DOCKER, OCI)"
  type        = string
  default     = "DOCKER"
}
