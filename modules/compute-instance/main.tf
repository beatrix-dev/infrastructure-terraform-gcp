# ---------------------------------------------------------------------------
# Zone discovery — lets instances rotate through zones without hardcoding names
# ---------------------------------------------------------------------------
data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# ---------------------------------------------------------------------------
# Instances — one per map entry
# ---------------------------------------------------------------------------
resource "google_compute_instance" "this" {
  for_each = var.instances

  name         = "${var.name_prefix}-${each.key}"
  project      = var.project_id
  zone         = local.instance_zones[each.key]
  machine_type = each.value.machine_type
  tags         = each.value.tags
  labels       = merge(var.labels, each.value.labels)

  boot_disk {
    initialize_params {
      image = each.value.image
      size  = each.value.disk_size_gb
      type  = each.value.disk_type
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id

    dynamic "access_config" {
      for_each = each.value.assign_external_ip ? [1] : []
      content {}
    }
  }

  metadata = merge(
    each.value.metadata,
    { enable-oslogin = "TRUE" },
    length(each.value.ssh_keys) > 0 ? { ssh-keys = join("\n", each.value.ssh_keys) } : {},
  )

  metadata_startup_script = each.value.startup_script

  service_account {
    email  = coalesce(each.value.service_account_email, data.google_compute_default_service_account.default.email)
    scopes = each.value.service_account_scopes
  }

  # Spot: reclaimable spare capacity, sometimes available in zones where
  # on-demand stock is exhausted. Standard: normal on-demand VM.
  scheduling {
    preemptible                 = each.value.spot
    provisioning_model          = each.value.spot ? "SPOT" : "STANDARD"
    automatic_restart           = each.value.spot ? false : true
    instance_termination_action = each.value.spot ? each.value.spot_termination_action : null
  }

  # The image argument resolves to a specific point-release at creation time;
  # don't force a replace when a newer point release becomes the family default.
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
