output "cluster_name" {
  value       = module.gke.cluster_name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = module.gke.cluster_endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "cluster_location" {
  value       = var.region
  description = "GKE cluster location (region)"
}

output "node_service_account_email" {
  value       = module.gke.node_service_account_email
  description = "Email of the GKE node service account"
}

output "kubeconfig_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
  description = "Command to update kubeconfig"
}

output "container_registry_url" {
  value       = module.container_registry.repository_url
  description = "Docker-pull URL for the container registry"
}

output "vpn_gateway_ips" {
  description = "GCP HA VPN external IPs — provide these to the remote peer to complete tunnel setup"
  value       = var.enable_vpn ? [module.vpn[0].vpn_gateway_ip_0, module.vpn[0].vpn_gateway_ip_1] : null
}
