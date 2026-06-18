###############################################################################
# autoscan-azure - convenience wrapper for Azure deployments.
#
# Combines identity-azure (account-level SP registration + workspace assignment)
# with the HiddenLayer autoscan root module into a single module call per
# workspace. Consumers only need to provide two Databricks provider aliases:
#   databricks.account   → https://accounts.azuredatabricks.net
#   databricks.workspace → the target workspace URL
#
# For multiple workspaces, instantiate this module once per workspace (with its
# own workspace provider alias) and share the same databricks.account provider.
# Only set create_databricks_service_principal = true in one workspace module;
# all others should use the default (false) to look up the already-registered SP.
###############################################################################

module "identity" {
  source = "../identity-azure"

  providers = {
    databricks.account = databricks.account
  }

  application_id                      = var.application_id
  databricks_workspace_ids            = [tostring(var.workspace_id)]
  create_databricks_service_principal = var.create_databricks_service_principal
  display_name                        = var.display_name
  workspace_permission                = var.workspace_permission
}

module "autoscan" {
  source = "../../"

  providers = {
    databricks = databricks.workspace
  }

  # var.application_id is a concrete value at plan time (consumer-provided),
  # so local.has_run_as in the root module resolves to true immediately and
  # count=1 for the permissions/grant resources on the very first apply.
  # depends_on enforces that the SP is created and workspace-assigned before
  # any autoscan resource is touched.
  run_as_service_principal_application_id = var.application_id
  depends_on                              = [module.identity]

  cluster_id                = var.cluster_id
  schemas                   = var.schemas
  hiddenlayer               = var.hiddenlayer
  hiddenlayer_client_id     = var.hiddenlayer_client_id
  hiddenlayer_client_secret = var.hiddenlayer_client_secret
  job_name                  = var.job_name
  quartz_cron               = var.quartz_cron
  timezone_id               = var.timezone_id
  pause_status              = var.pause_status
  max_active_scan_jobs      = var.max_active_scan_jobs
  manage_permissions        = var.manage_permissions
  manage_uc_grants          = var.manage_uc_grants
  cluster_permission_level  = var.cluster_permission_level
  workspace_base_directory  = var.workspace_base_directory
  notebook_version          = var.notebook_version
}
