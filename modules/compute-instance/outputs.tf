output "instance_names" {
  description = "Map of instance key -> instance name"
  value       = { for k, i in google_compute_instance.this : k => i.name }
}

output "instance_zones" {
  description = "Map of instance key -> zone it actually landed in (useful when zone_index picked it for you)"
  value       = local.instance_zones
}

output "internal_ips" {
  description = "Map of instance key -> internal IP"
  value       = { for k, i in google_compute_instance.this : k => i.network_interface[0].network_ip }
}

output "external_ips" {
  description = "Map of instance key -> external IP (null when assign_external_ip = false)"
  value = {
    for k, i in google_compute_instance.this :
    k => try(i.network_interface[0].access_config[0].nat_ip, null)
  }
}

output "ssh_commands" {
  description = "Map of instance key -> gcloud command to SSH in over IAP (no external IP required)"
  value = {
    for k, i in google_compute_instance.this :
    k => "gcloud compute ssh ${i.name} --zone=${i.zone} --project=${var.project_id} --tunnel-through-iap"
  }
}
