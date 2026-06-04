terraform {
  required_version = ">= 1.5"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.40"
    }
  }
}

# Auth is resolved by the provider's standard chain (env vars, ~/.databrickscfg
# profile, Azure CLI, OIDC, etc.). Only the host is set explicitly here.
provider "databricks" {
  host = var.databricks_host
}

module "hl_autoscan" {
  source = "../../"

  cluster_id = var.cluster_id
  schemas    = var.schemas

  # Optional but recommended for an unattended scheduled job.
  run_as_service_principal_application_id = var.run_as_sp_application_id

  hiddenlayer = {
    api_url       = "https://api.us.hiddenlayer.ai"
    client_id     = var.hl_client_id
    client_secret = var.hl_client_secret
    api_key_name  = "hiddenlayer-key"
  }

  quartz_cron = "0 0 */12 * * ?"
}

output "monitor_job_url" {
  value = module.hl_autoscan.job_url
}
