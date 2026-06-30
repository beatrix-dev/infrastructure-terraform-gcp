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

module "gke" {
  source = "./modules/gke"

  name_prefix         = var.cluster_name
  project_id          = var.project_id
  gcp_location        = local.zone
  network_id          = module.vpc.network_id
  subnetwork_id       = module.vpc.subnetwork_id
  pods_range_name     = "pods"
  services_range_name = "services"
  labels              = var.labels

  cluster_config = {
    name                    = var.cluster_name
    release_channel         = "REGULAR"
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
    master_authorized_networks = [
      {
        cidr_block   = "155.93.246.219/32"
        display_name = "home"
      }
    ]
    deletion_protection = false
  }
}

module "node_pools" {
  source = "./modules/node-pools"

  name_prefix                = var.cluster_name
  project_id                 = var.project_id
  gcp_location               = local.zone
  cluster_name               = module.gke.cluster_name
  node_service_account_email = module.gke.node_service_account_email
  labels                     = var.labels

  depends_on = [module.gke]

  node_pools = {
    default = {
      machine_type       = "e2-medium"
      disk_size_gb       = 30
      disk_type          = "pd-standard"
      initial_node_count = 1
      min_node_count     = 1
      max_node_count     = 3
      spot               = true
      labels             = {}
      taints             = []
      oauth_scopes       = ["https://www.googleapis.com/auth/cloud-platform"]
      accelerator        = null
    }
  }
}

module "container_registry" {
  source = "./modules/container-registry"

  project_id    = var.project_id
  repository_id = var.repository_id
  location      = var.region
  description   = "Container registry for ${var.cluster_name}"
}

module "database" {
  source = "./modules/database"

  database_config = {
    name          = "app-database"
    instance_name = "app-db-instance"
    location      = var.region
    version       = "MYSQL_8_0"
    tier          = "db-f1-micro"
    edition       = "ENTERPRISE"
  }
}

module "vpn" {
  count  = var.enable_vpn ? 1 : 0
  source = "./modules/vpn"

  name_prefix  = var.cluster_name
  project_id   = var.project_id
  gcp_region   = var.region
  network_id   = module.vpc.network_id
  network_name = module.vpc.network_name

  peer_tunnel_ips = var.vpn_peer_tunnel_ips
  peer_cidr       = var.vpn_peer_cidr
  shared_secret   = var.vpn_shared_secret
  peer_asn        = var.vpn_peer_asn

  labels     = local.common_labels
  depends_on = [module.vpc]
}
