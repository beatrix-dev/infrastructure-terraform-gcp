variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region used to auto-discover candidate zones (when var.zones is empty and an instance doesn't pin an explicit zone)"
  type        = string
}

variable "zones" {
  description = "Optional explicit candidate zone list to rotate through, e.g. [\"us-central1-a\", \"us-central1-b\"]. Leave empty to auto-discover every UP zone in var.region."
  type        = list(string)
  default     = []
}

variable "network_id" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "subnetwork_id" {
  description = "Self-link of the subnet the instances attach to"
  type        = string
}

variable "labels" {
  description = "Labels applied to all instances (merged with each instance's own labels)"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Instances — one google_compute_instance per map entry, each independently
# zone-flexible and spot-flexible.
#
# Zone selection per instance (in priority order):
#   1. `zone`       — pin an exact zone, e.g. "us-central1-a"
#   2. `zone_index` — otherwise, pick index N (wrapping) from var.zones, or
#                     from every UP zone in var.region if var.zones is empty.
#                     On a ZONE_RESOURCE_POOL_EXHAUSTED capacity error, bump
#                     zone_index and re-apply to try the next zone — no need
#                     to know exact zone names.
# ---------------------------------------------------------------------------
variable "instances" {
  description = "Map of instance name suffix -> instance configuration"
  type = map(object({
    machine_type = optional(string, "e2-micro")
    zone         = optional(string)
    zone_index   = optional(number, 0)

    image        = optional(string, "debian-cloud/debian-12")
    disk_size_gb = optional(number, 10)
    disk_type    = optional(string, "pd-standard")

    # Spot VMs use spare capacity at a discount (and are reclaimable), which
    # can also succeed in zones where on-demand stock is exhausted — useful
    # for free-tier/capacity-constrained testing. Set false for an on-demand VM.
    spot                    = optional(bool, true)
    spot_termination_action = optional(string, "STOP")

    # IAP-based SSH (`gcloud compute ssh --tunnel-through-iap`) works over the
    # internal IP alone — no external IP needed as long as the "ssh-enabled"
    # tag is present and the VPC's IAP firewall rule is in place.
    assign_external_ip = optional(bool, false)
    tags               = optional(list(string), ["ssh-enabled"])

    metadata       = optional(map(string), {})
    startup_script = optional(string)
    ssh_keys       = optional(list(string), [])

    service_account_email  = optional(string)
    service_account_scopes = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])

    labels = optional(map(string), {})
  }))
  default = {
    linux = {}
  }

  validation {
    condition     = alltrue([for i in var.instances : i.disk_size_gb >= 10])
    error_message = "disk_size_gb must be at least 10 for all instances"
  }

  validation {
    condition     = alltrue([for i in var.instances : contains(["pd-standard", "pd-balanced", "pd-ssd"], i.disk_type)])
    error_message = "disk_type must be pd-standard, pd-balanced, or pd-ssd for all instances"
  }

  validation {
    condition     = alltrue([for i in var.instances : contains(["STOP", "DELETE"], i.spot_termination_action)])
    error_message = "spot_termination_action must be STOP or DELETE for all instances"
  }
}
