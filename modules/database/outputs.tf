output "connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance) — used by the Cloud SQL Auth Proxy"
  value       = google_sql_database_instance.mysql_instance.connection_name
}

output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.mysql_instance.name
}

output "public_ip_address" {
  description = "Public IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.mysql_instance.public_ip_address
}
