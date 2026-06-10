variable "application_id" {
  type        = string
  description = "The Entra ID client/application ID of the pre-existing service principal. This is also the Databricks SP's application_id and the value passed to the root module's run_as_service_principal_application_id."
}

variable "databricks_workspace_id" {
  type        = number
  description = "Numeric Databricks workspace ID. Used by databricks_mws_permission_assignment to bind the service principal to the target workspace at the account level."
}

variable "workspace_permission" {
  type        = string
  description = "Workspace-level role to grant the service principal. Must be USER or ADMIN."
  default     = "USER"

  validation {
    condition     = contains(["USER", "ADMIN"], var.workspace_permission)
    error_message = "workspace_permission must be either USER or ADMIN."
  }
}

variable "display_name" {
  type        = string
  description = "Optional human-readable display name for the service principal. Informational only — the module looks up the SP by application_id."
  default     = null
}
