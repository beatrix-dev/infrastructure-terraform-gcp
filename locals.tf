locals {
  zone        = "${var.region}-a"
  name_prefix = var.cluster_name

  common_labels = merge(var.labels, {
    managed-by  = "terraform"
    environment = var.cluster_name
    region      = var.region
  })
}