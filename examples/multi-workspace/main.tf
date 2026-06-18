###############################################################################
# Multi-workspace example (Azure).
#
# Uses the autoscan-azure wrapper module so each workspace requires only one
# module block instead of separate identity-azure + root module calls.
#
# Terraform cannot for_each over provider configurations, so the pattern is:
#   - one aliased provider per workspace
#   - one module block per workspace, each receiving its workspace provider
#   - one shared account-level provider across all workspaces
#
# For larger fleets (5+ workspaces) prefer the CI matrix pattern in
# examples/ci-matrix/ — one apply per workspace, each with its own state.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.40"
    }
  }
}

# Shared account-level provider — one instance covers all workspaces.
provider "databricks" {
  alias               = "account"
  host                = "https://accounts.azuredatabricks.net"
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

provider "databricks" {
  alias               = "workspace_a"
  host                = var.workspace_a_host
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

provider "databricks" {
  alias               = "workspace_b"
  host                = var.workspace_b_host
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

# Workspace A — set create_databricks_service_principal = true to register the
# SP in the Databricks account for the first time.
module "hl_workspace_a" {
  source = "../../modules/autoscan-azure"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace_a
  }

  application_id                      = var.run_as_sp_application_id
  workspace_id                        = var.workspace_a_id
  create_databricks_service_principal = true

  cluster_id                = var.workspace_a_cluster_id
  schemas                   = var.workspace_a_schemas
  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret
}

# Workspace B — SP is already registered by the workspace_a module above, so
# create_databricks_service_principal stays false (the default).
module "hl_workspace_b" {
  source = "../../modules/autoscan-azure"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace_b
  }

  application_id = var.run_as_sp_application_id
  workspace_id   = var.workspace_b_id

  cluster_id                = var.workspace_b_cluster_id
  schemas                   = var.workspace_b_schemas
  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret
}

output "workspace_a_job_url" {
  value = module.hl_workspace_a.job_url
}

output "workspace_b_job_url" {
  value = module.hl_workspace_b.job_url
}
