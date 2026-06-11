output "repository_id" {
  description = "ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_url" {
  description = "Docker-pull URL for the repository (LOCATION-docker.pkg.dev/PROJECT/REPO)"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "name" {
  description = "Full resource name of the repository"
  value       = google_artifact_registry_repository.main.name
}
