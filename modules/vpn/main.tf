locals {
  # Stage-2 activates once all 4 AWS tunnel outside IPs are provided.
  # AWS exposes 2 separate Site-to-Site VPN connections (2 tunnels each) so that
  # every tunnel can terminate on one of the 2 GCP HA VPN interfaces:
  #   - tunnel 0 & tunnel 1 (AWS VPN connection #1) -> GCP interface 0
  #   - tunnel 2 & tunnel 3 (AWS VPN connection #2) -> GCP interface 1
  tunnels_active = length(var.peer_tunnel_ips) == 4

  # Routing mode must match what each AWS VPN connection was created with —
  # AWS doesn't let a connection mix static and dynamic (BGP) routing, and
  # GCP's HA VPN tunnels have to agree with whichever their AWS side uses.
  dynamic_routing = var.routing_mode == "DYNAMIC"
  static_routing  = var.routing_mode == "STATIC"

  # Destination CIDRs routed over the tunnels when static routing is used.
  # Falls back to peer_cidr so static mode works out of the box, but can be
  # narrowed/expanded independently (e.g. a specific AWS subnet instead of
  # the whole VPC CIDR).
  static_route_cidrs = length(var.static_route_destination_ranges) > 0 ? var.static_route_destination_ranges : (
    var.peer_cidr != null ? [var.peer_cidr] : []
  )
}

# ---------------------------------------------------------------------------
# Stage 1 — always created
# HA VPN Gateway: 2 external interfaces with auto-assigned GCP public IPs.
# Give vpn_gateway_ip_0 and vpn_gateway_ip_1 to AWS when creating the two
# Customer Gateways (one per interface IP) and their VPN connections.
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# Cloud Router — only needed for dynamic (BGP) routing. Not created in static
# mode since there's no BGP session and nothing else uses it.
resource "google_compute_router" "vpn" {
  count   = local.dynamic_routing ? 1 : 0
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
# Stage 2 — activates when all 4 AWS tunnel outside IPs are provided
# Two AWS Site-to-Site VPN connections (TWO_IPS_REDUNDANCY each) terminate on
# the same GCP HA VPN gateway, represented here as a single 4-interface peer
# gateway (FOUR_IPS_REDUNDANCY) — this is Google's documented topology for
# peering HA VPN with AWS at full (4-tunnel) redundancy.
# ---------------------------------------------------------------------------

# Represents the AWS side — 4 outside tunnel IPs across 2 VPN connections
resource "google_compute_external_vpn_gateway" "peer" {
  count           = local.tunnels_active ? 1 : 0
  name            = "${var.name_prefix}-aws-ext-gw"
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

# Tunnel 0 — GCP interface 0 <-> AWS VPN connection #1, tunnel 1
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
  router                          = local.dynamic_routing ? google_compute_router.vpn[0].id : null
  ike_version                     = 2
}

# Tunnel 1 — GCP interface 0 <-> AWS VPN connection #1, tunnel 2
resource "google_compute_vpn_tunnel" "tunnel1" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-1"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 1
  shared_secret                   = var.tunnel1_psk
  router                          = local.dynamic_routing ? google_compute_router.vpn[0].id : null
  ike_version                     = 2
}

# Tunnel 2 — GCP interface 1 <-> AWS VPN connection #2, tunnel 1
resource "google_compute_vpn_tunnel" "tunnel2" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-2"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 2
  shared_secret                   = var.tunnel2_psk
  router                          = local.dynamic_routing ? google_compute_router.vpn[0].id : null
  ike_version                     = 2
}

# Tunnel 3 — GCP interface 1 <-> AWS VPN connection #2, tunnel 2
resource "google_compute_vpn_tunnel" "tunnel3" {
  count                           = local.tunnels_active ? 1 : 0
  name                            = "${var.name_prefix}-tunnel-3"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = 3
  shared_secret                   = var.tunnel3_psk
  router                          = local.dynamic_routing ? google_compute_router.vpn[0].id : null
  ike_version                     = 2
}

# ---------------------------------------------------------------------------
# Dynamic routing (routing_mode = "DYNAMIC") — BGP sessions, one per tunnel.
# BGP link-local CIDRs are assigned by AWS — supplied via variables.
# ip_range on each interface is the GCP-side ("Customer gateway") inside IP;
# peer_ip_address on each peer is the AWS-side ("Virtual private gateway") inside IP.
# ---------------------------------------------------------------------------
resource "google_compute_router_interface" "tunnel0" {
  count      = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-0"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn[0].name
  ip_range   = var.bgp_tunnel0_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel0[0].name
}

resource "google_compute_router_interface" "tunnel1" {
  count      = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-1"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn[0].name
  ip_range   = var.bgp_tunnel1_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[0].name
}

resource "google_compute_router_interface" "tunnel2" {
  count      = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-2"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn[0].name
  ip_range   = var.bgp_tunnel2_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2[0].name
}

resource "google_compute_router_interface" "tunnel3" {
  count      = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name       = "${var.name_prefix}-if-tunnel-3"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn[0].name
  ip_range   = var.bgp_tunnel3_cidr
  vpn_tunnel = google_compute_vpn_tunnel.tunnel3[0].name
}

resource "google_compute_router_peer" "tunnel0" {
  count                     = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-0"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn[0].name
  peer_ip_address           = var.bgp_tunnel0_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel0[0].name
}

resource "google_compute_router_peer" "tunnel1" {
  count                     = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-1"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn[0].name
  peer_ip_address           = var.bgp_tunnel1_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1[0].name
}

resource "google_compute_router_peer" "tunnel2" {
  count                     = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-2"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn[0].name
  peer_ip_address           = var.bgp_tunnel2_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel2[0].name
}

resource "google_compute_router_peer" "tunnel3" {
  count                     = local.tunnels_active && local.dynamic_routing ? 1 : 0
  name                      = "${var.name_prefix}-peer-tunnel-3"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn[0].name
  peer_ip_address           = var.bgp_tunnel3_peer_ip
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel3[0].name
}

# ---------------------------------------------------------------------------
# Static routing (routing_mode = "STATIC") — one route per (tunnel x CIDR),
# all at the same priority so GCP does ECMP across whichever tunnels are up
# and automatically withdraws the route for any tunnel that goes down.
# ---------------------------------------------------------------------------
resource "google_compute_route" "static_tunnel0" {
  for_each            = local.tunnels_active && local.static_routing ? { for c in local.static_route_cidrs : c => c } : {}
  name                = "${var.name_prefix}-static-tunnel-0-${replace(each.value, "/[./]/", "-")}"
  project             = var.project_id
  network             = var.network_name
  dest_range          = each.value
  priority            = var.static_route_priority
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel0[0].id
}

resource "google_compute_route" "static_tunnel1" {
  for_each            = local.tunnels_active && local.static_routing ? { for c in local.static_route_cidrs : c => c } : {}
  name                = "${var.name_prefix}-static-tunnel-1-${replace(each.value, "/[./]/", "-")}"
  project             = var.project_id
  network             = var.network_name
  dest_range          = each.value
  priority            = var.static_route_priority
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1[0].id
}

resource "google_compute_route" "static_tunnel2" {
  for_each            = local.tunnels_active && local.static_routing ? { for c in local.static_route_cidrs : c => c } : {}
  name                = "${var.name_prefix}-static-tunnel-2-${replace(each.value, "/[./]/", "-")}"
  project             = var.project_id
  network             = var.network_name
  dest_range          = each.value
  priority            = var.static_route_priority
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel2[0].id
}

resource "google_compute_route" "static_tunnel3" {
  for_each            = local.tunnels_active && local.static_routing ? { for c in local.static_route_cidrs : c => c } : {}
  name                = "${var.name_prefix}-static-tunnel-3-${replace(each.value, "/[./]/", "-")}"
  project             = var.project_id
  network             = var.network_name
  dest_range          = each.value
  priority            = var.static_route_priority
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel3[0].id
}

# Allow inbound traffic from the AWS VPC CIDR (name kept as-is — renaming a
# firewall rule forces a destroy/recreate — see allow_peer_egress for the mirror)
resource "google_compute_firewall" "allow_peer" {
  count     = local.tunnels_active && var.peer_cidr != null ? 1 : 0
  name      = "${var.name_prefix}-allow-vpn-peer"
  project   = var.project_id
  network   = var.network_name
  direction = "INGRESS"

  allow {
    protocol = "all"
  }

  source_ranges = [var.peer_cidr]
}

# Allow outbound traffic to the AWS VPC CIDR — GCP's implied default-allow-egress
# rule already covers this, but this makes it explicit and independent of
# whether that implied rule is ever removed.
resource "google_compute_firewall" "allow_peer_egress" {
  count     = local.tunnels_active && var.peer_cidr != null ? 1 : 0
  name      = "${var.name_prefix}-allow-vpn-peer-out"
  project   = var.project_id
  network   = var.network_name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = [var.peer_cidr]
}
