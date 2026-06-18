###############################################################################
# Azure authentication — set via environment variables in CI:
#   TF_VAR_azure_tenant_id, TF_VAR_azure_client_id, TF_VAR_azure_client_secret
###############################################################################

variable "azure_tenant_id" {
  type        = string
  description = "Entra ID tenant ID."
}

variable "azure_client_id" {
  type        = string
  description = "Application (client) ID of the Terraform runner service principal."
}

variable "azure_client_secret" {
  type        = string
  sensitive   = true
  description = "Client secret for the Terraform runner service principal."
}

###############################################################################
# Workspace-specific — set per workspace via a .tfvars file
###############################################################################

variable "workspace_host" {
  type        = string
  description = "Databricks workspace URL (e.g. https://adb-1234567890123456.7.azuredatabricks.net)."
}

variable "workspace_id" {
  type        = string
  description = "Numeric Databricks workspace ID (the 15-digit number in the workspace URL)."
}

variable "cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID in this workspace."
}

variable "schemas" {
  type = list(object({
    catalog = string
    schema  = string
  }))
  description = "Catalog/schema pairs to monitor in this workspace."
}

variable "run_as_sp_application_id" {
  type        = string
  description = "Entra ID application ID of the run-as service principal."
}

variable "create_databricks_service_principal" {
  type        = bool
  description = "Register the SP in the Databricks account. Set true only for one workspace (the first); all others should be false."
  default     = false
}

###############################################################################
# HiddenLayer credentials — set via environment variables in CI:
#   TF_VAR_hl_client_id, TF_VAR_hl_client_secret
###############################################################################

variable "hl_client_id" {
  type        = string
  sensitive   = true
  description = "HiddenLayer API client ID (SaaS only)."
  default     = null
}

variable "hl_client_secret" {
  type        = string
  sensitive   = true
  description = "HiddenLayer API client secret (SaaS only)."
  default     = null
}
