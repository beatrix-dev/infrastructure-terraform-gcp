output "network_id" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnetwork_id" {
  description = "Self-link of the GKE subnet"
  value       = google_compute_subnetwork.main.id
}

output "subnetwork_name" {
  description = "Name of the GKE subnet"
  value       = google_compute_subnetwork.main.name
}

output "subnet_cidr" {
  description = "Primary CIDR block of the subnet (node IPs)"
  value       = google_compute_subnetwork.main.ip_cidr_range
}

output "nat_ips" {
  description = "Auto-allocated NAT IPs (available after first connection)"
  value       = var.vpc_config.enable_nat ? google_compute_router_nat.main[0].nat_ips : []
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = var.vpc_config.enable_nat ? google_compute_router.main[0].name : null
}
