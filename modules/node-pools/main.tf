# ---------------------------------------------------------------------------
# GKE Node Pools — one per map entry
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  name     = "${var.name_prefix}-${each.key}"
  location = var.gcp_location
  cluster  = var.cluster_name
  project  = var.project_id

  # Per-zone count; ignored after first apply (autoscaler manages it)
  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = each.value.disk_type
    spot            = each.value.spot
    service_account = var.node_service_account_email
    oauth_scopes    = each.value.oauth_scopes
    tags            = ["gke-node"]

    labels = merge(var.labels, each.value.labels)

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    dynamic "guest_accelerator" {
      for_each = each.value.accelerator != null ? [each.value.accelerator] : []
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count
        gpu_driver_installation_config {
          gpu_driver_version = guest_accelerator.value.gpu_driver_version
        }
      }
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # GKE_METADATA exposes Workload Identity to pods — required for IRSA-equivalent
    # workload_metadata_config {
    #   mode = "GKE_METADATA"
    # }

    resource_labels = merge(var.labels, { node-pool = each.key })
  }

  # Ignore autoscaler drift on initial_node_count after creation
  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
