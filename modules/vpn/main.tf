locals {
  # Stage-2 activates once all 4 peer tunnel IPs are provided
  tunnels_active = length(var.peer_tunnel_ips) == 4
}

# ---------------------------------------------------------------------------
# Stage 1 — always created
# HA VPN Gateway: 2 external interfaces with auto-assigned public IPs.
# Output these IPs to the remote peer to configure their side.
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# Cloud Router: handles BGP once tunnels are up. Kept separate from NAT router.
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
# Stage 2 — activates when peer_tunnel_ips contains exactly 4 IPs
# ---------------------------------------------------------------------------

# Represents the remote peer from GCP's perspective (4 tunnel outside IPs)
resource "google_compute_external_vpn_gateway" "peer" {
  count           = local.tunnels_active ? 1 : 0
  name            = "${var.name_prefix}-peer-ext-gw"
  project         = var.project_id
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = var.peer_tunnel_ips[0]
  }
  interface {
    id         = 1
    ip_address = var.peer_tunnel_ips[1]
  }
  interface {
    id         = 2
    ip_address = var.peer_tunnel_ips[2]
  }
  interface {
    id         = 3
    ip_address = var.peer_tunnel_ips[3]
  }
}

# 4 IPsec tunnels — full HA topology (GCP interface 0 → peer 0 & 2, interface 1 → peer 1 & 3)
resource "google_compute_vpn_tunnel" "tunnel0" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-0"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 0
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-1"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 1
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-2"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 2
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel3" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-3"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 3
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

# BGP link-local IPs — 169.254.10–13.x avoids ranges reserved by common remote peers
resource "google_compute_router_interface" "tunnel0" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-0"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.10.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel0[0].name
}

resource "google_compute_router_interface" "tunnel1" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-1"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.11.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[0].name
}

resource "google_compute_router_interface" "tunnel2" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-2"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.12.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2[0].name
}

resource "google_compute_router_interface" "tunnel3" {
  count      = local.tunnels_active ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-3"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.13.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel3[0].name
}

# BGP peers — GCP peers with the remote .1 address on each /30
resource "google_compute_router_peer" "tunnel0" {
  count                     = local.tunnels_active ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-0"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.10.1"
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
  peer_ip_address           = "169.254.11.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1[0].name
}

resource "google_compute_router_peer" "tunnel2" {
  count                     = local.tunnels_active ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-2"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.12.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel2[0].name
}

resource "google_compute_router_peer" "tunnel3" {
  count                     = local.tunnels_active ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-3"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.13.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel3[0].name
}

# Firewall — allow inbound traffic from the remote network (stage-2 only)
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
