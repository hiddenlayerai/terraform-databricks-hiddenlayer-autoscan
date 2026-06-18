variable "application_id" {
  type        = string
  description = "The Entra ID client/application ID of the pre-existing service principal. This is also the Databricks SP's application_id and the value passed to the root module's run_as_service_principal_application_id."
}

variable "databricks_workspace_ids" {
  type        = set(string)
  description = "Set of numeric Databricks workspace IDs to assign the service principal to. Accepts one or more workspace IDs, enabling a single module call to cover all workspaces."

  validation {
    condition     = length(var.databricks_workspace_ids) > 0
    error_message = "At least one workspace ID must be provided."
  }
}

variable "workspace_permission" {
  type        = string
  description = "Default workspace-level role to grant the service principal when a workspace is not listed in workspace_permission_overrides. Must be USER or ADMIN."
  default     = "USER"

  validation {
    condition     = contains(["USER", "ADMIN"], var.workspace_permission)
    error_message = "workspace_permission must be either USER or ADMIN."
  }
}

variable "workspace_permission_overrides" {
  type        = map(string)
  description = "Optional per-workspace role overrides, keyed by workspace ID (as a string). Values must be USER or ADMIN. Workspaces not present here use workspace_permission."
  default     = {}

  validation {
    condition = alltrue([
      for r in values(var.workspace_permission_overrides) : contains(["USER", "ADMIN"], r)
    ])
    error_message = "Every workspace_permission_overrides value must be either USER or ADMIN."
  }
}

variable "create_databricks_service_principal" {
  type        = bool
  description = "If true, register the Entra application as a Databricks account-level service principal instead of looking up a pre-existing one. Requires only the account-level provider credentials already used by this module (no azuread provider). The Entra application itself must already exist."
  default     = false
}

variable "display_name" {
  type        = string
  description = "Display name for the service principal. Used only when create_databricks_service_principal is true; the lookup path matches the SP by application_id. Defaults to 'HiddenLayer Autoscan'."
  default     = "HiddenLayer Autoscan"
}
