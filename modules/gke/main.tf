# ---------------------------------------------------------------------------
# Service Account for GKE nodes (least-privilege)
# ---------------------------------------------------------------------------
resource "google_service_account" "node_sa" {
  account_id   = "${var.name_prefix}-gke-node-sa"
  display_name = "GKE Node Service Account — ${var.cluster_config.name}"
  project      = var.project_id
}

resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",         # pull images from GCR
    "roles/artifactregistry.reader",      # pull images from Artifact Registry
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# ---------------------------------------------------------------------------
# GKE Cluster (regional — control plane spans all zones in the region)
# ---------------------------------------------------------------------------
resource "google_container_cluster" "main" {
  name     = var.cluster_config.name
  location = var.gcp_region
  project  = var.project_id

  # Remove the default node pool immediately — we manage pools separately
  # remove_default_node_pool = true
  # initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnetwork_id

  # VPC-native networking (alias IPs) — required for private clusters
  networking_mode = "VPC_NATIVE"

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

  # Workload Identity — lets Kubernetes SAs impersonate GCP SAs (replaces node SA key files)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
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

  # Binary Authorization — allow all in dev, tighten in prod
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  deletion_protection = var.cluster_config.deletion_protection

  resource_labels = var.labels
}
