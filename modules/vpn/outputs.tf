output "vpn_gateway_ip_0" {
  description = "External IP of GCP HA VPN interface 0 — give this to the remote peer as tunnel endpoint 1"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[0].ip_address
}

output "vpn_gateway_ip_1" {
  description = "External IP of GCP HA VPN interface 1 — give this to the remote peer as tunnel endpoint 2"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[1].ip_address
}

output "vpn_router_name" {
  description = "Name of the Cloud Router handling BGP for VPN"
  value       = google_compute_router.vpn.name
}

output "tunnels_active" {
  description = "True once peer tunnel IPs have been provided and tunnels are deployed"
  value       = local.tunnels_active
}
