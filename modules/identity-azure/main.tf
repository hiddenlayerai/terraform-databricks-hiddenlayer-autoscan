###############################################################################
# identity-azure - wire an Entra ID-backed Databricks service principal into a
# target workspace so the HiddenLayer root module can use it as the run_as
# identity for the scheduled monitor job.
#
# This module deals with the Databricks-side (account-level) service principal
# only. The underlying Entra ID application must already exist; it is not
# created here and no azuread provider is required.
###############################################################################

# Optionally register the existing Entra application as a Databricks
# account-level service principal. Uses only the account-level provider
# credentials already required by this module (no azuread provider).
resource "databricks_service_principal" "this" {
  count          = var.create_databricks_service_principal ? 1 : 0
  provider       = databricks.account
  application_id = var.application_id
  display_name   = var.display_name
}

# Look up the SP at the Databricks account level when not creating it here.
# Validates the SP exists before attempting workspace assignment and surfaces
# the internal Databricks principal_id (distinct from application_id).
data "databricks_service_principal" "this" {
  count          = var.create_databricks_service_principal ? 0 : 1
  provider       = databricks.account
  application_id = var.application_id
}

locals {
  # Resolve the internal Databricks principal ID from whichever path is active.
  sp_id = var.create_databricks_service_principal ? databricks_service_principal.this[0].id : data.databricks_service_principal.this[0].id
}

# Assign the SP to each target workspace.
# for_each over the workspace ID set means one module call covers all workspaces.
# If the SP was already assigned to a workspace out-of-band, Terraform will
# adopt the existing assignment idempotently on the first apply.
resource "databricks_mws_permission_assignment" "this" {
  for_each     = var.databricks_workspace_ids
  provider     = databricks.account
  workspace_id = tonumber(each.value)
  principal_id = local.sp_id
  permissions  = [lookup(var.workspace_permission_overrides, tostring(each.value), var.workspace_permission)]
}
