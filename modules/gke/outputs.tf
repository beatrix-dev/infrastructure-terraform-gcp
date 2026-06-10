output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "GKE API server endpoint (without https://)"
  value       = google_container_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
}

output "node_service_account_email" {
  description = "Email of the GKE node service account — attach extra roles here for Workload Identity bindings"
  value       = google_service_account.node_sa.email
}

output "node_service_account_id" {
  description = "Fully-qualified resource ID of the node service account"
  value       = google_service_account.node_sa.id
}

output "workload_identity_pool" {
  description = "Workload Identity pool identifier"
  value       = "${var.project_id}.svc.id.goog"
}
