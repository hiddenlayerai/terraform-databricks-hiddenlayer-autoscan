variable "workspace_a_host" {
  type        = string
  description = "Workspace A URL."
}

variable "workspace_b_host" {
  type        = string
  description = "Workspace B URL."
}

variable "workspace_a_cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID in workspace A."
}

variable "workspace_b_cluster_id" {
  type        = string
  description = "Existing UC-enabled cluster ID in workspace B."
}

variable "run_as_sp_application_id" {
  type        = string
  description = "Application ID of the service principal to run the jobs as."
  default     = null
}

variable "hl_client_id" {
  type      = string
  sensitive = true
  default   = null
}

variable "hl_client_secret" {
  type      = string
  sensitive = true
  default   = null
}
