variable "databricks_host" {
  type        = string
  description = "Databricks workspace URL. AWS: https://dbc-xxxx.cloud.databricks.com, Azure: https://adb-xxxx.N.azuredatabricks.net, GCP: https://xxxx.N.gcp.databricks.com"
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
