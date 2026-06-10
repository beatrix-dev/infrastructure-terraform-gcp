# ---------------------------------------------------------------------------
# VPC Network
# ---------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  mtu                     = 1460
}

# ---------------------------------------------------------------------------
# Subnet — single subnet with secondary ranges for pods and services
# (VPC-native GKE requires alias IP ranges)
# ---------------------------------------------------------------------------
resource "google_compute_subnetwork" "main" {
  name                     = "${var.name_prefix}-subnet"
  project                  = var.project_id
  region                   = var.gcp_region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.vpc_config.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.vpc_config.pods_range_name
    ip_cidr_range = var.vpc_config.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.vpc_config.services_range_name
    ip_cidr_range = var.vpc_config.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Cloud Router — required by Cloud NAT
# ---------------------------------------------------------------------------
resource "google_compute_router" "main" {
  count   = var.vpc_config.enable_nat ? 1 : 0
  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.gcp_region
  network = google_compute_network.main.id
}

# ---------------------------------------------------------------------------
# Cloud NAT — provides outbound internet for private nodes
# ---------------------------------------------------------------------------
resource "google_compute_router_nat" "main" {
  count   = var.vpc_config.enable_nat ? 1 : 0
  name    = "${var.name_prefix}-nat"
  project = var.project_id
  region  = var.gcp_region
  router  = google_compute_router.main[0].name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = var.vpc_config.nat_log_filter
  }
}

# ---------------------------------------------------------------------------
# Firewall Rules
# ---------------------------------------------------------------------------

# Allow intra-cluster traffic (node-to-node, pod-to-pod)
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.vpc_config.subnet_cidr,
    var.vpc_config.pods_cidr,
  ]
}

# Allow IAP (Identity-Aware Proxy) SSH — no bastion needed
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.name_prefix}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-enabled"]
}

# Allow GKE master to reach node kubelet and webhook ports
resource "google_compute_firewall" "allow_master_to_nodes" {
  name    = "${var.name_prefix}-allow-master-nodes"
  project = var.project_id
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "10250"]
  }

  source_ranges = ["172.16.0.0/28"] # matches master_ipv4_cidr_block in cluster_config
  target_tags   = ["gke-node"]
}
