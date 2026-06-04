variable "databricks_host" {
  type        = string
  description = "Workspace URL, e.g. https://adb-1234567890123456.7.azuredatabricks.net"
}

variable "cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID to run the monitor job on."
}

variable "schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Catalog/schema pairs to monitor."
}

variable "run_as_sp_application_id" {
  type        = string
  description = "Application ID of the service principal to run the job as."
  default     = null
}

variable "hl_client_id" {
  type        = string
  description = "HiddenLayer API client ID."
  sensitive   = true
  default     = null
}

variable "hl_client_secret" {
  type        = string
  description = "HiddenLayer API client secret."
  sensitive   = true
  default     = null
}
