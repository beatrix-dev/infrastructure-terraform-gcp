# ---------------------------------------------------------------------------
# GCP HA VPN Gateway — 2 interfaces, each gets a public IP automatically
# ---------------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn-gw"
  project = var.project_id
  region  = var.gcp_region
  network = var.network_id
}

# ---------------------------------------------------------------------------
# Dedicated Cloud Router for VPN BGP (separate from the NAT router)
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
# AWS Virtual Private Gateway — attached to the target VPC
# ---------------------------------------------------------------------------
resource "aws_vpn_gateway" "main" {
  vpc_id          = var.aws_vpc_id
  amazon_side_asn = var.aws_asn

  tags = { Name = "${var.name_prefix}-vgw" }
}

# ---------------------------------------------------------------------------
# AWS Customer Gateways — one per GCP HA VPN interface
# ---------------------------------------------------------------------------
resource "aws_customer_gateway" "gcp_if0" {
  bgp_asn    = var.gcp_asn
  ip_address = google_compute_ha_vpn_gateway.main.vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = { Name = "${var.name_prefix}-cgw-0" }
}

resource "aws_customer_gateway" "gcp_if1" {
  bgp_asn    = var.gcp_asn
  ip_address = google_compute_ha_vpn_gateway.main.vpn_interfaces[1].ip_address
  type       = "ipsec.1"

  tags = { Name = "${var.name_prefix}-cgw-1" }
}

# ---------------------------------------------------------------------------
# AWS VPN Connections (dynamic/BGP routing)
# conn0 peers with GCP interface 0, conn1 peers with GCP interface 1
# Each connection yields 2 tunnel outside IPs → 4 total for GCP tunnels
# Inside CIDRs: AWS takes .1, GCP takes .2 in each /30
# ---------------------------------------------------------------------------
resource "aws_vpn_connection" "conn0" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.gcp_if0.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel1_preshared_key = var.shared_secret
  tunnel2_inside_cidr   = "169.254.11.0/30"
  tunnel2_preshared_key = var.shared_secret

  tags = { Name = "${var.name_prefix}-vpn-conn-0" }
}

resource "aws_vpn_connection" "conn1" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.gcp_if1.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.12.0/30"
  tunnel1_preshared_key = var.shared_secret
  tunnel2_inside_cidr   = "169.254.13.0/30"
  tunnel2_preshared_key = var.shared_secret

  tags = { Name = "${var.name_prefix}-vpn-conn-1" }
}

# ---------------------------------------------------------------------------
# External VPN Gateway — represents the AWS VGW from GCP's perspective
# 4 interfaces map to the 4 AWS tunnel outside IPs
# ---------------------------------------------------------------------------
resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${var.name_prefix}-aws-ext-gw"
  project         = var.project_id
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.conn0.tunnel1_address
  }
  interface {
    id         = 1
    ip_address = aws_vpn_connection.conn0.tunnel2_address
  }
  interface {
    id         = 2
    ip_address = aws_vpn_connection.conn1.tunnel1_address
  }
  interface {
    id         = 3
    ip_address = aws_vpn_connection.conn1.tunnel2_address
  }
}

# ---------------------------------------------------------------------------
# GCP VPN Tunnels — 4 tunnels for full HA
# tunnel0/1 use GCP interface 0; tunnel2/3 use GCP interface 1
# ---------------------------------------------------------------------------
resource "google_compute_vpn_tunnel" "tunnel0" {
  name                            = "${var.name_prefix}-tunnel-0"
  project                         = var.project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
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
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
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
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
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
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = 3
  shared_secret                   = var.shared_secret
  router                          = google_compute_router.vpn.id
  ike_version                     = 2
}

# ---------------------------------------------------------------------------
# Cloud Router Interfaces — bind each tunnel to a BGP link-local IP
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
# BGP Peers — GCP peers with AWS's .1 address on each /30
# ---------------------------------------------------------------------------
resource "google_compute_router_peer" "tunnel0" {
  name                      = "${var.name_prefix}-peer-tunnel-0"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.10.1"
  peer_asn                  = var.aws_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel0.name
}

resource "google_compute_router_peer" "tunnel1" {
  name                      = "${var.name_prefix}-peer-tunnel-1"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.11.1"
  peer_asn                  = var.aws_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1.name
}

resource "google_compute_router_peer" "tunnel2" {
  name                      = "${var.name_prefix}-peer-tunnel-2"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.12.1"
  peer_asn                  = var.aws_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel2.name
}

resource "google_compute_router_peer" "tunnel3" {
  name                      = "${var.name_prefix}-peer-tunnel-3"
  project                   = var.project_id
  region                    = var.gcp_region
  router                    = google_compute_router.vpn.name
  peer_ip_address           = "169.254.13.1"
  peer_asn                  = var.aws_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel3.name
}

# ---------------------------------------------------------------------------
# AWS Route Propagation — pushes GCP routes into specified route tables
# ---------------------------------------------------------------------------
resource "aws_vpn_gateway_route_propagation" "main" {
  for_each       = toset(var.aws_route_table_ids)
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = each.value
}

# ---------------------------------------------------------------------------
# GCP Firewall — allow all traffic originating from the AWS VPC CIDR
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_aws" {
  name    = "${var.name_prefix}-allow-aws"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "all"
  }

  source_ranges = [var.aws_vpc_cidr]
}
