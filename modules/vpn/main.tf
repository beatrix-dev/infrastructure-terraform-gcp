locals {
  # Stage-2 activates once peer tunnel IPs are provided — either shape works:
  #   - 1 IP  : a single peer device (e.g. FortiGate or other on-prem
  #             appliance) — one tunnel, terminated on GCP interface 0 only.
  #             Trades the 99.99% HA VPN SLA for 99.9% (no interface-level
  #             failover), same as classic VPN.
  #   - 4 IPs : AWS Site-to-Site VPN topology — AWS always creates 2 tunnels
  #             per VPN connection, so full (99.99%) redundancy against GCP's
  #             2-interface HA VPN gateway needs 2 AWS VPN connections:
  #               - tunnel 0 & tunnel 1 (AWS VPN connection #1) -> GCP interface 0
  #               - tunnel 2 & tunnel 3 (AWS VPN connection #2) -> GCP interface 1
  tunnel_count   = length(var.peer_tunnel_ips)
  tunnels_active = contains([1, 4], local.tunnel_count)

  redundancy_type = local.tunnel_count == 4 ? "FOUR_IPS_REDUNDANCY" : "SINGLE_IP_INTERNALLY_REDUNDANT"

  # Which GCP HA VPN interface each tunnel index terminates on.
  gateway_interface_by_tunnel = local.tunnel_count == 4 ? [0, 0, 1, 1] : [0]

  # Routing mode must match what the peer side was configured with — AWS
  # doesn't let a VPN connection mix static and dynamic (BGP) routing, and
  # GCP's HA VPN tunnels have to agree with whichever the peer uses.
  dynamic_routing = var.routing_mode == "DYNAMIC"
  static_routing  = var.routing_mode == "STATIC"

  # Destination CIDRs routed over the tunnels when static routing is used.
  # Falls back to peer_cidr so static mode works out of the box, but can be
  # narrowed/expanded independently (e.g. a specific subnet instead of the
  # whole peer CIDR).
  static_route_cidrs = length(var.static_route_destination_ranges) > 0 ? var.static_route_destination_ranges : (
    var.peer_cidr != null ? [var.peer_cidr] : []
  )
}

# ---------------------------------------------------------------------------
# Stage 1 — always created
# HA VPN Gateway: 2 external interfaces with auto-assigned GCP public IPs.
# Give vpn_gateway_ip_0 (and, for a 4-tunnel/AWS peer, vpn_gateway_ip_1 too)
# to the peer when setting up its side of the tunnel(s).
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# Cloud Router — every HA VPN tunnel must reference one, even under static
# routing (GCP rejects tunnel creation with an empty `router` field either
# way). What routing_mode actually changes is whether a BGP session gets
# attached to it: see google_compute_router_interface/_peer (DYNAMIC) vs
# google_compute_route (STATIC) below.
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
# Stage 2 — activates once peer_tunnel_ips has 1 (single device) or 4 (AWS)
# entries. Resources below are all count/for_each-driven off tunnel_count so
# the same module handles either shape.
# ---------------------------------------------------------------------------

# Represents the peer side — 1 interface for a single device, or 4 across
# 2 AWS VPN connections for the AWS topology.
resource "google_compute_external_vpn_gateway" "peer" {
  count           = local.tunnels_active ? 1 : 0
  name            = "${var.name_prefix}-ext-gw"
  project         = var.project_id
  redundancy_type = local.redundancy_type

  dynamic "interface" {
    for_each = range(local.tunnel_count)
    content {
      id         = interface.value
      ip_address = var.peer_tunnel_ips[interface.value]
    }
  }
}

resource "google_compute_vpn_tunnel" "tunnel" {
  count                           = local.tunnels_active ? local.tunnel_count : 0
  name                            = "${var.name_prefix}-tunnel-${count.index}"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = local.gateway_interface_by_tunnel[count.index]
  peer_external_gateway           = google_compute_external_vpn_gateway.peer[0].id
  peer_external_gateway_interface = count.index
  shared_secret                   = var.tunnel_psks[count.index]
  router                          = google_compute_router.vpn.id
  ike_version                     = 2

  lifecycle {
    precondition {
      condition     = length(var.tunnel_psks) == local.tunnel_count
      error_message = "tunnel_psks must have exactly one entry per peer_tunnel_ips entry (expected ${local.tunnel_count})."
    }
  }
}

# ---------------------------------------------------------------------------
# Dynamic routing (routing_mode = "DYNAMIC") — one BGP session per tunnel.
# BGP link-local CIDRs are assigned by the peer — supplied via variables.
# ip_range is the GCP-side inside IP; peer_ip_address is the peer-side inside IP.
# ---------------------------------------------------------------------------
resource "google_compute_router_interface" "tunnel" {
  count      = local.tunnels_active && local.dynamic_routing ? local.tunnel_count : 0
  name       = "${var.name_prefix}-if-tunnel-${count.index}"
  project    = var.project_id
  region     = var.gcp_region
  router     = google_compute_router.vpn.name
  ip_range   = var.bgp_tunnel_cidrs[count.index]
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[count.index].name

  lifecycle {
    precondition {
      condition     = length(var.bgp_tunnel_cidrs) == local.tunnel_count
      error_message = "bgp_tunnel_cidrs must have exactly one entry per peer_tunnel_ips entry (expected ${local.tunnel_count}) when routing_mode = DYNAMIC."
    }
  }
}

resource "google_compute_router_peer" "tunnel" {
  count                     = local.tunnels_active && local.dynamic_routing ? local.tunnel_count : 0
  name                      = "${var.name_prefix}-peer-tunnel-${count.index}"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = var.bgp_tunnel_peer_ips[count.index]
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel[count.index].name

  lifecycle {
    precondition {
      condition     = length(var.bgp_tunnel_peer_ips) == local.tunnel_count
      error_message = "bgp_tunnel_peer_ips must have exactly one entry per peer_tunnel_ips entry (expected ${local.tunnel_count}) when routing_mode = DYNAMIC."
    }
  }
}

# ---------------------------------------------------------------------------
# Static routing (routing_mode = "STATIC") — one route per (tunnel x CIDR),
# all at the same priority so GCP does ECMP across whichever tunnels are up
# and automatically withdraws the route for any tunnel that goes down.
# ---------------------------------------------------------------------------
resource "google_compute_route" "static_tunnel" {
  for_each = local.tunnels_active && local.static_routing ? {
    for pair in setproduct(range(local.tunnel_count), local.static_route_cidrs) :
    "${pair[0]}-${pair[1]}" => { tunnel_index = pair[0], cidr = pair[1] }
  } : {}

  name                = "${var.name_prefix}-static-tunnel-${each.value.tunnel_index}-${replace(each.value.cidr, "/[./]/", "-")}"
  project             = var.project_id
  network             = var.network_name
  dest_range          = each.value.cidr
  priority            = var.static_route_priority
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.value.tunnel_index].id
}

# Allow inbound traffic from the peer CIDR (name kept as-is — renaming a
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

# Allow outbound traffic to the peer CIDR — GCP's implied default-allow-egress
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
