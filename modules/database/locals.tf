locals {
  connection_name = "${var.database_config.location}:${var.database_config.instance_name}"
}
