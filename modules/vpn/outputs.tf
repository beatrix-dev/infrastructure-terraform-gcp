output "gcp_vpn_gateway_ip_0" {
  description = "External IP of GCP HA VPN interface 0 (used as AWS Customer Gateway 0)"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[0].ip_address
}

output "gcp_vpn_gateway_ip_1" {
  description = "External IP of GCP HA VPN interface 1 (used as AWS Customer Gateway 1)"
  value       = google_compute_ha_vpn_gateway.main.vpn_interfaces[1].ip_address
}

output "aws_vpn_gateway_id" {
  description = "AWS Virtual Private Gateway ID"
  value       = aws_vpn_gateway.main.id
}

output "aws_vpn_connection_ids" {
  description = "AWS Site-to-Site VPN Connection IDs"
  value       = [aws_vpn_connection.conn0.id, aws_vpn_connection.conn1.id]
}

output "gcp_vpn_router_name" {
  description = "Name of the Cloud Router handling VPN BGP sessions"
  value       = google_compute_router.vpn.name
}
