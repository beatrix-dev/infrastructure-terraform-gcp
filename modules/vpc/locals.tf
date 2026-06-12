locals {
  network_name = "${var.name_prefix}-vpc"
  subnet_name  = "${var.name_prefix}-subnet"
  router_name  = "${var.name_prefix}-router"
  nat_name     = "${var.name_prefix}-nat"
  fw_internal  = "${var.name_prefix}-allow-internal"
  fw_iap_ssh   = "${var.name_prefix}-allow-iap-ssh"
  fw_master    = "${var.name_prefix}-allow-master-nodes"
}
