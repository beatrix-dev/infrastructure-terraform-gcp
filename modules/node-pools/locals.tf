locals {
  spot_pools    = { for name, pool in var.node_pools : name => pool if pool.spot }
  gpu_pools     = { for name, pool in var.node_pools : name => pool if pool.accelerator != null }
  machine_types = toset([for _, pool in var.node_pools : pool.machine_type])
}
