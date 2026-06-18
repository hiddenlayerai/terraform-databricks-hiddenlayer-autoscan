###############################################################################
# Azure authentication (shared across all workspaces and the account provider)
###############################################################################

variable "azure_tenant_id" {
  type        = string
  description = "Entra ID tenant ID."
}

variable "azure_client_id" {
  type        = string
  description = "Application (client) ID of the service principal used to authenticate Terraform."
}

variable "azure_client_secret" {
  type        = string
  sensitive   = true
  description = "Client secret for the Terraform runner service principal."
}

###############################################################################
# Run-as identity (shared across all workspaces)
###############################################################################

variable "run_as_sp_application_id" {
  type        = string
  description = "Entra ID application ID of the service principal that will run the HiddenLayer monitor jobs."
}

###############################################################################
# Workspace A
###############################################################################

variable "workspace_a_host" {
  type        = string
  description = "Workspace A URL (e.g. https://adb-111.7.azuredatabricks.net)."
}

variable "workspace_a_id" {
  type        = string
  description = "Numeric Databricks workspace ID for workspace A."
}

variable "workspace_a_cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID in workspace A."
}

variable "workspace_a_schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Catalog/schema pairs to monitor in workspace A."
}

###############################################################################
# Workspace B
###############################################################################

variable "workspace_b_host" {
  type        = string
  description = "Workspace B URL (e.g. https://adb-222.7.azuredatabricks.net)."
}

variable "workspace_b_id" {
  type        = string
  description = "Numeric Databricks workspace ID for workspace B."
}

variable "workspace_b_cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID in workspace B."
}

variable "workspace_b_schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Catalog/schema pairs to monitor in workspace B."
}

###############################################################################
# HiddenLayer credentials (shared)
###############################################################################

variable "hl_client_id" {
  type        = string
  sensitive   = true
  description = "HiddenLayer API client ID."
  default     = null
}

variable "hl_client_secret" {
  type        = string
  sensitive   = true
  description = "HiddenLayer API client secret."
  default     = null
}
