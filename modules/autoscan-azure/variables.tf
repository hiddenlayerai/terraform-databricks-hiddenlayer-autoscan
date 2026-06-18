###############################################################################
# Identity (account-level, from identity-azure)
###############################################################################

variable "application_id" {
  type        = string
  description = "Entra ID client/application ID of the pre-existing service principal that will run the HiddenLayer monitor job."
}

variable "workspace_id" {
  type        = string
  description = "Numeric Databricks workspace ID (the 15-digit number in the workspace URL). Used to assign the service principal to this workspace at the account level."
}

variable "create_databricks_service_principal" {
  type        = bool
  description = "If true, register the Entra application as a Databricks account-level service principal. Set to true for the first workspace when the SP does not yet exist in the Databricks account; leave false for all subsequent workspaces that share the same SP."
  default     = false
}

variable "display_name" {
  type        = string
  description = "Optional display name applied when create_databricks_service_principal is true."
  default     = null
}

variable "workspace_permission" {
  type        = string
  description = "Workspace-level role to assign to the service principal. Must be USER or ADMIN."
  default     = "USER"

  validation {
    condition     = contains(["USER", "ADMIN"], var.workspace_permission)
    error_message = "workspace_permission must be either USER or ADMIN."
  }
}

###############################################################################
# HiddenLayer configuration (from root module)
###############################################################################

variable "cluster_id" {
  type        = string
  description = "ID of an existing Databricks cluster (with Unity Catalog access) that the scheduled monitor job will run on."
}

variable "schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Unity Catalog catalog/schema pairs to monitor for new model versions."

  validation {
    condition     = length(var.schemas) > 0
    error_message = "At least one catalog/schema pair must be provided."
  }
}

variable "hiddenlayer" {
  description = "HiddenLayer Model Scanner endpoint configuration. Defaults target the US SaaS region."
  type = object({
    api_url      = optional(string, "https://api.us.hiddenlayer.ai")
    auth_url     = optional(string, "https://auth.hiddenlayer.ai")
    console_url  = optional(string, "https://console.us.hiddenlayer.ai")
    api_key_name = optional(string, "hiddenlayer-key")
  })
  default = {}
}

variable "hiddenlayer_client_id" {
  type        = string
  description = "HiddenLayer API client ID. Required for the SaaS scanner; omit for an Enterprise (self-hosted) scanner."
  sensitive   = true
  default     = null
}

variable "hiddenlayer_client_secret" {
  type        = string
  description = "HiddenLayer API client secret. Required for the SaaS scanner; omit for an Enterprise (self-hosted) scanner."
  sensitive   = true
  default     = null
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
  description = "Quartz cron expression controlling how often the monitor job polls for new model versions."
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
  description = "Maximum number of concurrent scan jobs the monitor notebook will spawn."
  default     = 10
}

###############################################################################
# Permissions / grants
###############################################################################

variable "manage_permissions" {
  type        = bool
  description = "When true, grant the run-as SP the cluster/job/secret-scope permissions it needs to run and spawn scan jobs."
  default     = true
}

variable "manage_uc_grants" {
  type        = bool
  description = "When true, grant the run-as SP the Unity Catalog privileges needed to list models and write scan-status tags."
  default     = true
}

variable "cluster_permission_level" {
  type        = string
  description = "Permission level granted to the run-as SP on the cluster."
  default     = "CAN_RESTART"
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
  description = "Version segment appended to workspace_base_directory to namespace the uploaded notebooks."
  default     = "0.2.1"
}
