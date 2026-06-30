locals {
  # Stage-2 activates once both AWS tunnel outside IPs are provided
  tunnels_active = length(var.peer_tunnel_ips) == 2
}

# ---------------------------------------------------------------------------
# Stage 1 — always created
# HA VPN Gateway: 2 external interfaces with auto-assigned GCP public IPs.
# Give vpn_gateway_ip_0 and vpn_gateway_ip_1 to AWS when creating the VGW attachment.
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# Cloud Router — handles BGP sessions for both tunnels
resource "google_compute_router" "vpn" {
  name    = "${var.name_prefix}-vpn-router"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id

  bgp {
    asn               = var.gcp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

# ---------------------------------------------------------------------------
# Stage 2 — activates when both AWS tunnel outside IPs are provided
# AWS Site-to-Site VPN uses TWO_IPS_REDUNDANCY (one VPN connection = 2 tunnels)
# ---------------------------------------------------------------------------

# Represents the AWS VGW — 2 outside tunnel IPs
resource "google_compute_external_vpn_gateway" "peer" {
  count           = local.tunnels_active ? 1 : 0
  name            = "${var.name_prefix}-aws-ext-gw"
  project         = var.project_id
  redundancy_type = "TWO_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = var.peer_tunnel_ips[0]
  }
  interface {
    id         = 1
    ip_address = var.peer_tunnel_ips[1]
  }
}

# Tunnel 0 — GCP interface 0 <-> AWS tunnel 1
resource "google_compute_vpn_tunnel" "tunnel0" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-0"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 0
  shared_secret                   = var.tunnel0_psk
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

# Tunnel 1 — GCP interface 1 <-> AWS tunnel 2
resource "google_compute_vpn_tunnel" "tunnel1" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-1"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 1
  shared_secret                   = var.tunnel1_psk
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

# BGP link-local CIDRs are assigned by AWS — supplied via variables
resource "google_compute_router_interface" "tunnel0" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-0"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = var.bgp_tunnel0_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel0[0].name
}

resource "google_compute_router_interface" "tunnel1" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-1"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = var.bgp_tunnel1_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[0].name
}

resource "google_compute_router_peer" "tunnel0" {
  count                     = local.tunnels_active ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-0"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = var.bgp_tunnel0_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel0[0].name
}

resource "google_compute_router_peer" "tunnel1" {
  count                     = local.tunnels_active ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-1"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = var.bgp_tunnel1_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1[0].name
}

# Allow inbound traffic from the AWS VPC CIDR
resource "google_compute_firewall" "allow_peer" {
  count   = local.tunnels_active && var.peer_cidr != null ? 1 : 0
  name    = "${var.name_prefix}-allow-vpn-peer"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "all"
  }

  source_ranges = [var.peer_cidr]
}
