###############################################################################
# Multi-workspace example.
#
# Terraform cannot `for_each` over provider configurations, so the idiomatic
# pattern is one aliased provider per workspace and one module block per
# workspace, each receiving its provider via the `providers` meta-argument.
#
# For many workspaces, prefer instantiating this module once per workspace from
# your CI/pipeline (separate state per workspace) instead of stamping them all
# into a single root module/state.
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

provider "databricks" {
  alias = "workspace_a"
  host  = var.workspace_a_host
}

provider "databricks" {
  alias = "workspace_b"
  host  = var.workspace_b_host
}

module "hl_autoscan_a" {
  source    = "../../"
  providers = { databricks = databricks.workspace_a }

  cluster_id = var.workspace_a_cluster_id
  schemas    = [{ catalog = "production_catalog", schema = "models" }]

  run_as_service_principal_application_id = var.run_as_sp_application_id
  hiddenlayer = {
    api_url       = "https://api.us.hiddenlayer.ai"
    client_id     = var.hl_client_id
    client_secret = var.hl_client_secret
  }
}

module "hl_autoscan_b" {
  source    = "../../"
  providers = { databricks = databricks.workspace_b }

  cluster_id = var.workspace_b_cluster_id
  schemas    = [{ catalog = "research_catalog", schema = "experiments" }]

  run_as_service_principal_application_id = var.run_as_sp_application_id
  hiddenlayer = {
    api_url       = "https://api.us.hiddenlayer.ai"
    client_id     = var.hl_client_id
    client_secret = var.hl_client_secret
  }
}
