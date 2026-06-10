output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "cluster_location" {
  value       = google_container_cluster.primary.location
  description = "GKE cluster location (zone)"
}

output "node_count" {
  value       = google_container_node_pool.primary_nodes.node_count
  description = "Number of nodes in cluster"
}

output "kubeconfig_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --zone us-central1-a --project ${var.project_id}"
  description = "Command to update kubeconfig"
}
