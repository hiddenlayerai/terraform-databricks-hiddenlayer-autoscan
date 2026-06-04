###############################################################################
# HiddenLayer Databricks autoscan - core (workspace-scoped, cloud-agnostic)
#
# Reproduces what `hldbx autoscan` does, declaratively:
#   1. (SaaS only) a Databricks-backed secret scope + secret per catalog.schema
#   2. uploads the 4 HiddenLayer python files to a versioned workspace folder
#   3. creates the scheduled monitor job that polls for new model versions
#   4. grants the run-as service principal the permissions it needs to run
#      (and to spawn scan jobs at runtime) - something the CLI does not do.
###############################################################################

locals {
  # Normalize the API URL and detect SaaS vs Enterprise (self-hosted) scanner,
  # mirroring Config.UsesEnterpriseModelScanner() in the Go CLI.
  api_url_trimmed = trimsuffix(var.hiddenlayer.api_url, "/")
  is_enterprise   = !endswith(local.api_url_trimmed, ".hiddenlayer.ai")

  # Versioned workspace folder, e.g. /Shared/HiddenLayer/0.2.1
  workspace_dir = "${var.workspace_base_directory}/${var.notebook_version}"

  has_run_as    = var.run_as_service_principal_application_id != null
  manage_perms  = var.manage_permissions && local.has_run_as
  manage_grants = var.manage_uc_grants && local.has_run_as

  # Notebooks (carry the "# Databricks notebook source" header -> imported as notebooks).
  notebooks = {
    hl_monitor_models = "${path.module}/notebooks/hl_monitor_models.py"
    hl_scan_model     = "${path.module}/notebooks/hl_scan_model.py"
    hl_test           = "${path.module}/notebooks/hl_test.py"
  }

  # catalog.schema => object, used for scopes, secrets, ACLs and grants.
  schema_map = { for s in var.schemas : "${s.catalog}.${s.schema}" => s }
  catalogs   = toset([for s in var.schemas : s.catalog])

  # Secret scopes are only used by the SaaS scanner.
  scopes = local.is_enterprise ? {} : local.schema_map
}

###############################################################################
# Workspace assets
###############################################################################

resource "databricks_directory" "hl" {
  path = local.workspace_dir
}

# hl_common.py has NO notebook header; it must remain a plain workspace file so
# the notebooks can `from hl_common import *`.
resource "databricks_workspace_file" "hl_common" {
  path   = "${local.workspace_dir}/hl_common.py"
  source = "${path.module}/notebooks/hl_common.py"

  depends_on = [databricks_directory.hl]
}

resource "databricks_notebook" "notebooks" {
  for_each = local.notebooks

  path   = "${local.workspace_dir}/${each.key}"
  source = each.value

  depends_on = [databricks_directory.hl]
}

###############################################################################
# HiddenLayer credentials (SaaS only) -> Databricks secret store
# Convention "client_id:client_secret" must match the python notebooks.
###############################################################################

resource "databricks_secret_scope" "hl" {
  for_each = local.scopes

  name = "hl_scan.${each.value.catalog}.${each.value.schema}"
}

resource "databricks_secret" "hl" {
  for_each = local.scopes

  scope        = databricks_secret_scope.hl[each.key].name
  key          = var.hiddenlayer.api_key_name
  string_value = "${var.hiddenlayer.client_id}:${var.hiddenlayer.client_secret}"

  lifecycle {
    precondition {
      condition     = var.hiddenlayer.client_id != null && var.hiddenlayer.client_secret != null
      error_message = "hiddenlayer.client_id and hiddenlayer.client_secret are required when using the SaaS scanner (api_url ending in .hiddenlayer.ai)."
    }
  }
}

# Let the run-as SP read the credentials it will use at scan time.
resource "databricks_secret_acl" "hl" {
  for_each = local.has_run_as ? local.scopes : {}

  scope      = databricks_secret_scope.hl[each.key].name
  principal  = var.run_as_service_principal_application_id
  permission = "READ"
}

###############################################################################
# Scheduled monitor job - the cron-driven centerpiece.
# Databricks' own Jobs scheduler fires this on var.quartz_cron.
###############################################################################

resource "databricks_job" "monitor" {
  name = var.job_name

  schedule {
    quartz_cron_expression = var.quartz_cron
    timezone_id            = var.timezone_id
    pause_status           = var.pause_status
  }

  task {
    task_key            = "monitor"
    existing_cluster_id = var.cluster_id

    notebook_task {
      notebook_path = databricks_notebook.notebooks["hl_monitor_models"].path
      base_parameters = {
        MAX_ACTIVE_SCAN_JOBS = tostring(var.max_active_scan_jobs)
      }
    }
  }

  # Job-level parameters, mirroring the Go JobParameterDefinition list.
  parameter {
    name    = "schemas"
    default = jsonencode([for s in var.schemas : { catalog = s.catalog, schema = s.schema }])
  }
  parameter {
    name    = "hl_api_key_name"
    default = local.is_enterprise ? "" : var.hiddenlayer.api_key_name
  }
  parameter {
    name    = "hl_api_url"
    default = local.api_url_trimmed
  }
  parameter {
    name    = "hl_auth_url"
    default = var.hiddenlayer.auth_url
  }
  parameter {
    name    = "hl_console_url"
    default = local.is_enterprise ? "" : var.hiddenlayer.console_url
  }

  dynamic "run_as" {
    for_each = local.has_run_as ? [1] : []
    content {
      service_principal_name = var.run_as_service_principal_application_id
    }
  }

  depends_on = [
    databricks_workspace_file.hl_common,
    databricks_secret.hl,
  ]
}

###############################################################################
# Permissions the CLI never sets, but the run-as SP needs at runtime.
###############################################################################

resource "databricks_permissions" "cluster" {
  count = local.manage_perms ? 1 : 0

  cluster_id = var.cluster_id

  access_control {
    service_principal_name = var.run_as_service_principal_application_id
    permission_level       = var.cluster_permission_level
  }
}

resource "databricks_permissions" "job" {
  count = local.manage_perms ? 1 : 0

  job_id = databricks_job.monitor.id

  access_control {
    service_principal_name = var.run_as_service_principal_application_id
    permission_level       = "CAN_MANAGE_RUN"
  }
}

# Unity Catalog privileges so the SP can list models and write scan-status tags.
# databricks_grant (singular) is additive - it does not clobber other grants.
resource "databricks_grant" "catalog" {
  for_each = local.manage_grants ? local.catalogs : toset([])

  catalog    = each.value
  principal  = var.run_as_service_principal_application_id
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "schema" {
  for_each = local.manage_grants ? local.schema_map : {}

  schema     = "${each.value.catalog}.${each.value.schema}"
  principal  = var.run_as_service_principal_application_id
  privileges = ["USE_SCHEMA", "EXECUTE", "APPLY_TAG"]
}
