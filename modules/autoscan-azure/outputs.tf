output "job_id" {
  description = "ID of the scheduled HiddenLayer monitor job."
  value       = module.autoscan.job_id
}

output "job_url" {
  description = "Workspace URL of the scheduled monitor job."
  value       = module.autoscan.job_url
}

output "workspace_directory" {
  description = "Workspace directory the HiddenLayer notebooks were uploaded to."
  value       = module.autoscan.workspace_directory
}

output "application_id" {
  description = "Entra ID application ID of the run-as service principal. Matches the application_id input; exposed for reference."
  value       = module.identity.application_id
}

output "service_principal_id" {
  description = "Internal Databricks principal ID of the run-as service principal."
  value       = module.identity.service_principal_id
}
