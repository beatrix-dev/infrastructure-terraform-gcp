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
  }
}