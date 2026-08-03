resource "google_sql_database" "mysql_database" {
  name     = var.database_config.name
  instance = google_sql_database_instance.mysql_instance.name
}

resource "google_sql_database_instance" "mysql_instance" {
  name                = var.database_config.instance_name
  region              = var.database_config.location
  database_version    = var.database_config.version
  deletion_protection = var.database_config.deletion_protection

  settings {
    tier              = var.database_config.tier
    disk_size         = var.database_config.disk_size_gb
    disk_type         = var.database_config.disk_type
    edition           = var.database_config.edition
    availability_type = var.database_config.availability_type

    ip_configuration {
      ipv4_enabled = var.database_config.ip_configuration.ipv4_enabled
      ssl_mode     = var.database_config.ip_configuration.require_ssl ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      dynamic "authorized_networks" {
        for_each = var.database_config.ip_configuration.authorized_networks
        content {
          value = authorized_networks.value.value
          name  = authorized_networks.value.name
        }
      }
    }
  }
}