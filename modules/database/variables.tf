variable "database_config" {
  description = "Cloud SQL instance configuration"
  type = object({
    name                = string
    instance_name       = string
    location            = string
    version             = string
    tier                = string
    edition             = string
    disk_size_gb        = optional(number, 20)
    disk_type           = optional(string, "PD_SSD")
    availability_type   = optional(string, "ZONAL")
    deletion_protection = optional(bool, false)

    ip_configuration = optional(object({
      ipv4_enabled = optional(bool, true)
      require_ssl  = optional(bool, true)
      authorized_networks = optional(list(object({
        value = string
        name  = optional(string)
      })), [])
    }), {})
  })

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.database_config.edition)
    error_message = "edition must be ENTERPRISE or ENTERPRISE_PLUS"
  }

  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.database_config.availability_type)
    error_message = "availability_type must be REGIONAL or ZONAL"
  }

  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.database_config.disk_type)
    error_message = "disk_type must be PD_SSD or PD_HDD"
  }

  validation {
    condition     = var.database_config.disk_size_gb >= 20
    error_message = "disk_size_gb minimum is 20"
  }
}