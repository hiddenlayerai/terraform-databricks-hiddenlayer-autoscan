output "application_id" {
  description = "The Entra ID client/application ID of the service principal. Pass this to the root module's run_as_service_principal_application_id."
  value       = data.databricks_service_principal.this.application_id
}

output "service_principal_id" {
  description = "The internal Databricks principal ID of the service principal (distinct from the application_id). Useful for referencing this SP in other account-level resources."
  value       = data.databricks_service_principal.this.id
}
