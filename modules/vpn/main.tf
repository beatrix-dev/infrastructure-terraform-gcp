# ---------------------------------------------------------------------------
# HA VPN Gateway — 2 external interfaces, each automatically assigned a
# public IP. These IPs are what the remote peer connects to.
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# ---------------------------------------------------------------------------
# Cloud Router — handles BGP route exchange with the remote peer.
# Kept separate from the NAT router so VPN and egress concerns are isolated.
# ---------------------------------------------------------------------------
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
# External VPN Gateway — GCP's representation of the remote peer.
# FOUR_IPS_REDUNDANCY maps to 4 tunnel endpoints on the remote side,
# giving full HA across both GCP interfaces.
# ---------------------------------------------------------------------------
resource "google_compute_external_vpn_gateway" "peer" {
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

# ---------------------------------------------------------------------------
# VPN Tunnels — 4 tunnels for full HA (Google-recommended topology).
# GCP interface 0 → peer interfaces 0 & 2
# GCP interface 1 → peer interfaces 1 & 3
# ---------------------------------------------------------------------------
resource "google_compute_vpn_tunnel" "tunnel0" {
  name                            = "${var.name_prefix}-tunnel-0"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  name                            = "${var.name_prefix}-tunnel-1"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer.id
  peer_external_gateway_interface = 1
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  name                            = "${var.name_prefix}-tunnel-2"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer.id
  peer_external_gateway_interface = 2
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "tunnel3" {
  name                            = "${var.name_prefix}-tunnel-3"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer.id
  peer_external_gateway_interface = 3
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

# ---------------------------------------------------------------------------
# Cloud Router Interfaces — one per tunnel, using 169.254.10–13.x/30.
# Ranges 169.254.0–5.x are reserved by AWS so these are avoided for
# cross-cloud compatibility. GCP takes .2, remote peer takes .1.
# ---------------------------------------------------------------------------
resource "google_compute_router_interface" "tunnel0" {
  name       = "${var.name_prefix}-if-tunnel-0"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.10.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel0.name
}

resource "google_compute_router_interface" "tunnel1" {
  name       = "${var.name_prefix}-if-tunnel-1"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.11.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1.name
}

resource "google_compute_router_interface" "tunnel2" {
  name       = "${var.name_prefix}-if-tunnel-2"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.12.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2.name
}

resource "google_compute_router_interface" "tunnel3" {
  name       = "${var.name_prefix}-if-tunnel-3"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = "169.254.13.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel3.name
}

# ---------------------------------------------------------------------------
# BGP Peers — GCP peers with the remote .1 address on each /30
# ---------------------------------------------------------------------------
resource "google_compute_router_peer" "tunnel0" {
  name                      = "${var.name_prefix}-peer-tunnel-0"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.10.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel0.name
}

resource "google_compute_router_peer" "tunnel1" {
  name                      = "${var.name_prefix}-peer-tunnel-1"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.11.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1.name
}

resource "google_compute_router_peer" "tunnel2" {
  name                      = "${var.name_prefix}-peer-tunnel-2"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.12.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel2.name
}

resource "google_compute_router_peer" "tunnel3" {
  name                      = "${var.name_prefix}-peer-tunnel-3"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.13.1"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel3.name
}

# ---------------------------------------------------------------------------
# Firewall — allow traffic from the remote peer network into this VPC
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_peer" {
  name    = "${var.name_prefix}-allow-vpn-peer"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "all"
  }

  source_ranges = [var.peer_cidr]
}
