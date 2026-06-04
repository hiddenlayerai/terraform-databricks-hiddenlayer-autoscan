output "job_id" {
  description = "ID of the scheduled HiddenLayer monitor job."
  value       = databricks_job.monitor.id
}

output "job_url" {
  description = "Workspace URL of the scheduled monitor job."
  value       = databricks_job.monitor.url
}

output "workspace_directory" {
  description = "Workspace directory the HiddenLayer notebooks were uploaded to."
  value       = local.workspace_dir
}

output "secret_scope_names" {
  description = "Names of the Databricks secret scopes created for HiddenLayer credentials (empty for the Enterprise scanner)."
  value       = [for s in databricks_secret_scope.hl : s.name]
}

output "is_enterprise_scanner" {
  description = "Whether the module was configured for an Enterprise (self-hosted) scanner."
  value       = local.is_enterprise
}
