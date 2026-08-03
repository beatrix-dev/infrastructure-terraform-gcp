# ---------------------------------------------------------------------------
# Service Account for GKE nodes (least-privilege)
# ---------------------------------------------------------------------------
resource "google_service_account" "node_sa" {
  account_id   = local.node_sa_id
  display_name = "GKE Node Service Account — ${var.cluster_config.name}"
  project      = var.project_id
}

resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",    # pull images from GCR
    "roles/artifactregistry.reader", # pull images from Artifact Registry
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_sa.email}"

  depends_on = [google_service_account.node_sa]

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# GKE Cluster (zonal — single zone avoids 3x node multiplication cost)
# ---------------------------------------------------------------------------
resource "google_container_cluster" "main" {
  name     = var.cluster_config.name
  location = var.gcp_location
  project  = var.project_id

  # DO NOT use remove_default_node_pool = true — it races with cluster bootstrap
  # and causes apply to hang 20-40+ min. Manage the default pool in-place instead.
  initial_node_count = 1

  network    = var.network_id
  subnetwork = var.subnetwork_id

  # VPC-native networking (alias IPs) — required for private clusters
  networking_mode = "VPC_NATIVE"

  node_config {
    machine_type = "e2-medium"
    disk_type    = "pd-standard"
    disk_size_gb = 30
    spot         = false

    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["gke-node"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = var.cluster_config.enable_private_nodes
    enable_private_endpoint = var.cluster_config.enable_private_endpoint
    master_ipv4_cidr_block  = var.cluster_config.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.cluster_config.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = var.cluster_config.release_channel
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary Authorization — allow all in dev, tighten in prod
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  deletion_protection = var.cluster_config.deletion_protection

  resource_labels = var.labels

  # Prevent accidental cluster destruction
  lifecycle {
    ignore_changes = [
      node_config,
      node_pool,
      node_locations,
      initial_node_count,
    ]
  }

  depends_on = [google_service_account.node_sa]
}
