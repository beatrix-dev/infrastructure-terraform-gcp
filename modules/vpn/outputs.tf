output "vpn_gateway_ip_0" {
  description = "External IP of GCP HA VPN interface 0 — use this as the Customer Gateway IP for AWS VPN connection #1 (tunnels 0 & 1)"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[0].ip_address
}

output "vpn_gateway_ip_1" {
  description = "External IP of GCP HA VPN interface 1 — use this as the Customer Gateway IP for AWS VPN connection #2 (tunnels 2 & 3)"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[1].ip_address
}

output "vpn_router_name" {
  description = "Name of the Cloud Router handling BGP for VPN (null in STATIC routing_mode — no router is created)"
  value       = local.dynamic_routing ? google_compute_router.vpn[0].name : null
}

output "tunnels_active" {
  description = "True once peer tunnel IPs have been provided and tunnels are deployed"
  value       = local.tunnels_active
}

output "routing_mode" {
  description = "Routing mode currently applied to the tunnels (DYNAMIC or STATIC)"
  value       = var.routing_mode
}

output "static_route_names" {
  description = "Names of the static routes created (empty unless routing_mode = STATIC)"
  value = local.static_routing ? concat(
    [for r in google_compute_route.static_tunnel0 : r.name],
    [for r in google_compute_route.static_tunnel1 : r.name],
    [for r in google_compute_route.static_tunnel2 : r.name],
    [for r in google_compute_route.static_tunnel3 : r.name],
  ) : []
}
