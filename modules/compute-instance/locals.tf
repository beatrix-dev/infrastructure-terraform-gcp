locals {
  # Explicit zones win; otherwise fall back to every currently-UP zone in the region
  zone_pool = length(var.zones) > 0 ? var.zones : data.google_compute_zones.available.names

  # Resolved zone per instance, wrapping zone_index so any integer is safe to pass
  instance_zones = {
    for key, cfg in var.instances :
    key => coalesce(cfg.zone, local.zone_pool[cfg.zone_index % length(local.zone_pool)])
  }
}
