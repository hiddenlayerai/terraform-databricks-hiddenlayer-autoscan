###############################################################################
# identity-azure - wire a pre-existing Entra ID-backed Databricks service
# principal into a target workspace so the HiddenLayer root module can use it
# as the run_as identity for the scheduled monitor job.
###############################################################################

# Look up the pre-existing SP at the Databricks account level.
# Validates the SP exists before attempting workspace assignment and surfaces
# the internal Databricks principal_id (distinct from application_id).
data "databricks_service_principal" "this" {
  provider       = databricks.account
  application_id = var.application_id
}

# Assign the SP to each target workspace.
# for_each over the workspace ID set means one module call covers all workspaces.
# If the SP was already assigned to a workspace out-of-band, Terraform will
# adopt the existing assignment idempotently on the first apply.
resource "databricks_mws_permission_assignment" "this" {
  for_each     = var.databricks_workspace_ids
  provider     = databricks.account
  workspace_id = each.value
  principal_id = data.databricks_service_principal.this.id
  permissions  = [var.workspace_permission]
}
