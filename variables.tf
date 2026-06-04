###############################################################################
# Required inputs
###############################################################################

variable "cluster_id" {
  type        = string
  description = "ID of an existing Databricks cluster (with Unity Catalog access) that the scheduled monitor job will run on. Mirrors `dbx_cluster_id` in the hldbx CLI."
}

variable "schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Unity Catalog catalog/schema pairs to monitor for new model versions. Mirrors `dbx_schemas` in the hldbx CLI."

  validation {
    condition     = length(var.schemas) > 0
    error_message = "At least one catalog/schema pair must be provided."
  }
}

###############################################################################
# HiddenLayer configuration
###############################################################################

variable "hiddenlayer" {
  description = <<-EOT
    HiddenLayer Model Scanner configuration.

    For the SaaS scanner (api_url ending in `.hiddenlayer.ai`) `client_id`,
    `client_secret` and `api_key_name` are required: the module stores
    `client_id:client_secret` in a Databricks-backed secret scope per schema.

    For an Enterprise (self-hosted) scanner, set `api_url` to your scanner URL
    and leave the credentials null - no secret scope is created.
  EOT

  type = object({
    api_url       = optional(string, "https://api.us.hiddenlayer.ai")
    auth_url      = optional(string, "https://auth.hiddenlayer.ai")
    console_url   = optional(string, "https://console.us.hiddenlayer.ai")
    api_key_name  = optional(string, "hiddenlayer-key")
    client_id     = optional(string)
    client_secret = optional(string)
  })

  default   = {}
  sensitive = true
}

###############################################################################
# Job scheduling
###############################################################################

variable "job_name" {
  type        = string
  description = "Name of the scheduled monitor job created in Databricks."
  default     = "hl_find_new_model_versions"
}

variable "quartz_cron" {
  type        = string
  description = "Quartz cron expression controlling how often the monitor job polls for new model versions. Defaults to every 12 hours. Mirrors `dbx_polling_quartz_cron`."
  default     = "0 0 */12 * * ?"
}

variable "timezone_id" {
  type        = string
  description = "Java timezone ID used to evaluate the cron schedule."
  default     = "UTC"
}

variable "pause_status" {
  type        = string
  description = "Whether the scheduled job is active on apply. One of PAUSED or UNPAUSED."
  default     = "UNPAUSED"

  validation {
    condition     = contains(["PAUSED", "UNPAUSED"], var.pause_status)
    error_message = "pause_status must be either PAUSED or UNPAUSED."
  }
}

variable "max_active_scan_jobs" {
  type        = number
  description = "Maximum number of concurrent scan jobs the monitor notebook will spawn. Mirrors `dbx_max_active_scan_jobs`."
  default     = 10
}

###############################################################################
# Run-as identity
###############################################################################

variable "run_as_service_principal_application_id" {
  type        = string
  description = "Application ID of an existing Databricks service principal to run the scheduled job as. If null, the job runs as the identity that created it (the Terraform principal). Mirrors `dbx_run_as`."
  default     = null
}

###############################################################################
# Workspace layout
###############################################################################

variable "workspace_base_directory" {
  type        = string
  description = "Base workspace directory under which versioned notebook folders are created."
  default     = "/Shared/HiddenLayer"
}

variable "notebook_version" {
  type        = string
  description = "Version segment appended to workspace_base_directory to namespace the uploaded notebooks (e.g. /Shared/HiddenLayer/<notebook_version>). Bumping this performs a side-by-side upgrade."
  default     = "0.2.1"
}

###############################################################################
# Permissions / grants (the bits the CLI does NOT do today)
###############################################################################

variable "manage_permissions" {
  type        = bool
  description = "When true and a run-as service principal is set, grant that SP the cluster/job/secret-scope permissions it needs to run (and to spawn scan jobs at runtime)."
  default     = true
}

variable "manage_uc_grants" {
  type        = bool
  description = "When true and a run-as service principal is set, grant that SP the Unity Catalog privileges needed to list models and write scan-status tags. Requires the Terraform principal to be able to manage grants."
  default     = true
}

variable "cluster_permission_level" {
  type        = string
  description = "Permission level granted to the run-as SP on the cluster."
  default     = "CAN_RESTART"
}
