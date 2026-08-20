module "vpc" {
  source = "./modules/vpc"

  name_prefix = var.cluster_name
  project_id  = var.project_id
  gcp_region  = var.region
  labels      = var.labels

  vpc_config = {
    network_name        = "${var.cluster_name}-vpc"
    subnet_cidr         = "10.0.0.0/24"
    pods_cidr           = "10.1.0.0/16"
    services_cidr       = "10.2.0.0/20"
    pods_range_name     = "pods"
    services_range_name = "services"
    enable_nat          = true
    nat_log_filter      = "ERRORS_ONLY"
  }
}

# Disabled for now — testing with modules.compute-instance instead (cheaper,
# no capacity/quota fights). Uncomment when back to GKE-based testing.
#
# module "gke" {
#   source = "./modules/gke"
#
#   name_prefix         = var.cluster_name
#   project_id          = var.project_id
#   gcp_location        = local.zone
#   network_id          = module.vpc.network_id
#   subnetwork_id       = module.vpc.subnetwork_id
#   pods_range_name     = "pods"
#   services_range_name = "services"
#   labels              = var.labels
#
#   cluster_config = {
#     name                    = var.cluster_name
#     release_channel         = "REGULAR"
#     enable_private_nodes    = true
#     enable_private_endpoint = false
#     master_ipv4_cidr_block  = "172.16.0.0/28"
#     master_authorized_networks = [
#       {
#         cidr_block   = "155.93.246.219/32"
#         display_name = "home"
#       }
#     ]
#     deletion_protection = false
#   }
# }
#
# module "container_registry" {
#   source = "./modules/container-registry"
#
#   project_id    = var.project_id
#   repository_id = var.repository_id
#   location      = var.region
#   description   = "Container registry for ${var.cluster_name}"
# }
#
# module "database" {
#   source = "./modules/database"
#
#   database_config = {
#     name          = "app-database"
#     instance_name = "app-db-instance"
#     location      = var.region
#     version       = "MYSQL_8_0"
#     tier          = "db-f1-micro"
#     edition       = "ENTERPRISE"
#   }
# }

module "instance" {
  source = "./modules/compute-instance"

  name_prefix   = var.cluster_name
  project_id    = var.project_id
  region        = var.region
  network_id    = module.vpc.network_id
  subnetwork_id = module.vpc.subnetwork_id
  labels        = local.common_labels

  instances = {
    linux = {
      machine_type = "e2-micro"
      spot         = true
      # Capacity error in this zone? Bump zone_index and re-apply — cycles
      # through every UP zone in var.region without needing exact names.
      zone_index = 0
    }
  }

  depends_on = [module.vpc]
}

module "vpn" {
  source = "./modules/vpn"

  name_prefix  = var.cluster_name
  project_id   = var.project_id
  gcp_region   = var.region
  network_id   = module.vpc.network_id
  network_name = module.vpc.network_name

  peer_tunnel_ips = var.vpn_peer_tunnel_ips
  peer_cidr       = var.vpn_peer_cidr
  peer_asn        = var.vpn_peer_asn

  routing_mode                    = var.vpn_routing_mode
  static_route_destination_ranges = var.vpn_static_route_destination_ranges
  static_route_priority           = var.vpn_static_route_priority

  tunnel_psks = var.vpn_tunnel_psks

  bgp_tunnel_cidrs    = var.vpn_bgp_tunnel_cidrs
  bgp_tunnel_peer_ips = var.vpn_bgp_tunnel_peer_ips

  labels     = local.common_labels
  depends_on = [module.vpc]
}
