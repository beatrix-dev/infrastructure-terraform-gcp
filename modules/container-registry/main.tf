resource "google_artifact_registry_repository" "main" {
  repository_id = var.repository_id
  description   = var.description
  location      = var.location
  project       = var.project_id
  format        = var.format

  docker_config {
    immutable_tags = false
  }
}