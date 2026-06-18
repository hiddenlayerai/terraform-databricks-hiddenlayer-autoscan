###############################################################################
# CI matrix example — single parameterized root, one apply per workspace.
#
# This file is identical for every workspace. Workspace-specific values come
# from a per-workspace .tfvars file passed via -var-file at plan/apply time.
# Each workspace gets its own Terraform state (keyed by workspace ID or name).
#
# See github-workflow.yml for a GitHub Actions matrix that drives this pattern.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.40"
    }
  }

  # Configure your remote backend here. The workspace_key_prefix / key should
  # incorporate the workspace ID so each apply gets its own state.
  # Example (Azure Blob):
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstate"
  #   container_name       = "hl-autoscan"
  #   key                  = "placeholder"   # overridden via -backend-config at init
  # }
}

provider "databricks" {
  alias               = "account"
  host                = "https://accounts.azuredatabricks.net"
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

provider "databricks" {
  alias               = "workspace"
  host                = var.workspace_host
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

module "hl" {
  source = "../../modules/autoscan-azure"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace
  }

  application_id                      = var.run_as_sp_application_id
  workspace_id                        = var.workspace_id
  create_databricks_service_principal = var.create_databricks_service_principal

  cluster_id                = var.cluster_id
  schemas                   = var.schemas
  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret
}

output "job_url" {
  value = module.hl.job_url
}
