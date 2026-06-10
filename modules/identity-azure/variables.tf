variable "application_id" {
  type        = string
  description = "The Entra ID client/application ID of the pre-existing service principal. This is also the Databricks SP's application_id and the value passed to the root module's run_as_service_principal_application_id."
}

variable "databricks_workspace_ids" {
  type        = set(number)
  description = "Set of numeric Databricks workspace IDs to assign the service principal to. Accepts one or more workspace IDs, enabling a single module call to cover all workspaces."

  validation {
    condition     = length(var.databricks_workspace_ids) > 0
    error_message = "At least one workspace ID must be provided."
  }
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
