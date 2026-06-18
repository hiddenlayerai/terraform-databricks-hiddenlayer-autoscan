# identity-azure

Optional submodule that wires an Entra ID-backed Databricks service principal
into a target workspace so the HiddenLayer root module can use it as the
`run_as` identity for the scheduled monitor job.

There are two distinct identity layers involved:

1. **Entra (Azure AD) application / service principal** — the actual identity in
   Microsoft Entra ID. This submodule **never** creates this; it must already
   exist, and no `azuread` provider is involved.
2. **Databricks account-level service principal** — the Databricks-side record
   that references the Entra application by `application_id`. This submodule can
   either **look it up** (default) or **create it** for you via
   `create_databricks_service_principal = true`, using only the account-level
   Databricks credentials it already requires.

It then ensures the SP has workspace access via
`databricks_mws_permission_assignment`.

## Prerequisites

- An Azure Entra ID application / service principal already created (layer 1).
- The application registered as a Databricks account-level service principal
  (layer 2). Set `create_databricks_service_principal = true` to have this
  submodule register it, or do it out-of-band (Databricks account console, CLI,
  or another Terraform config) and leave the default lookup behavior.
- A Databricks **account-level** provider configured alongside the workspace
  provider in the consumer root config.

## Usage

```hcl
provider "databricks" {
  alias         = "account"
  host          = "https://accounts.azuredatabricks.net"
  azure_tenant_id       = var.azure_tenant_id
  azure_client_id       = var.azure_client_id
  azure_client_secret   = var.azure_client_secret
}

provider "databricks" {
  host                  = "https://<workspace>.azuredatabricks.net"
  azure_tenant_id       = var.azure_tenant_id
  azure_client_id       = var.azure_client_id
  azure_client_secret   = var.azure_client_secret
}

module "hl_identity" {
  source = "./modules/identity-azure"

  providers = {
    databricks.account = databricks.account
  }

  application_id           = "00000000-0000-0000-0000-000000000000"
  databricks_workspace_ids = ["123456789012345"]  # add more IDs for multi-workspace

  # Optional: register the Databricks account-level SP instead of looking it up.
  # create_databricks_service_principal = true

  # Optional: override the role for specific workspaces (keyed by workspace ID).
  # workspace_permission_overrides = { "123456789012345" = "ADMIN" }
}

module "hiddenlayer" {
  source = "path/to/terraform-databricks-hiddenlayer-autoscan"

  run_as_service_principal_application_id = module.hl_identity.application_id

  # depends_on is required when using this module alongside identity-azure.
  #
  # The application_id output is a pass-through of var.application_id (always
  # known at plan time), which allows the root module to correctly plan the
  # permissions and grant resources on the first apply. However, without
  # depends_on, Terraform may attempt to create autoscan resources before the
  # SP has been assigned to the workspace, causing run_as errors.
  depends_on = [module.hl_identity]

  cluster_id  = var.cluster_id
  schemas     = var.schemas
  hiddenlayer = { api_url = "https://api.us.hiddenlayer.ai" }
}
```

## MLflow experiment permissions

The scan job downloads model artifacts using the `run_id` stored on each model
version. That `run_id` points to the original **training run**, which lives
inside an MLflow experiment owned by the data scientist who registered the
model. Without a `run_as` SP the job runs as the job owner (typically a
workspace admin who can see all experiments); with an SP set to `USER`
workspace permission, that implicit access is lost.

**Recommended fix (Terraform only):** set `workspace_permission = "ADMIN"` so
the SP has the same experiment visibility as a workspace admin:

```hcl
module "hl_identity" {
  source = "./modules/identity-azure"
  ...
  workspace_permission = "ADMIN"
}
```

Per-workspace override variant:

```hcl
workspace_permission_overrides = { "123456789012345" = "ADMIN" }
```

If you cannot grant admin access, the scan notebook automatically falls back to
the model version's `source` URI when `PERMISSION_DENIED` is returned for the
`run_id` path — this covers all standard UC-registered models. The only case
where the fallback is unavailable is a model version that has a `run_id` but no
`source` URI (non-standard or very old registration flows). For that edge case,
grant `CAN_READ` on the specific experiment manually:

**Databricks UI:** Workspace → select the experiment → Permissions → add the
SP → `Can Read`.

**Databricks CLI:**
```bash
databricks permissions set experiments <experiment-id> \
  --json '{"access_control_list": [{"service_principal_name": "<sp-app-id>", "permission_level": "CAN_READ"}]}'
```

## `run_as` permission — manual step required

The Databricks Terraform provider does not currently support setting permissions
on service principals (`/api/2.0/permissions/servicePrincipals/{id}`) via the
`databricks_permissions` resource. As a result, Terraform cannot automatically
grant the `admins` group `CAN_USE` on the newly-created SP.

If `terraform apply` fails with:

```
'<app-id>' cannot be set as run_as service principal, because it doesn't exist.
```

Grant `CAN_USE` to the workspace `admins` group manually **after** the SP is
assigned to the workspace, then re-run `apply`:

**Databricks UI:** Workspace → Admin settings → Service Principals → select the
SP → Permissions → add `admins` → `Can Use`.

**Databricks CLI:**
```bash
databricks permissions set service-principals <internal-sp-id> \
  --json '{"access_control_list": [{"group_name": "admins", "permission_level": "CAN_USE"}]}'
```

The `<internal-sp-id>` is the numeric Databricks principal ID exposed by this
module's `service_principal_id` output — not the Entra `application_id`. The
easiest way to retrieve it is to re-export it as a root-level output in your
consumer config:

```hcl
output "run_as_sp_id" {
  value = module.hl_identity.service_principal_id
  # or, if using the autoscan-azure wrapper:
  # value = module.hl.service_principal_id
}
```

Then after `terraform apply`:

```bash
terraform output run_as_sp_id
```

Alternatively, read it directly from state without adding an output:

```bash
terraform show -json | jq '
  .values.root_module.child_modules[]
  | select(.address == "module.hl_identity")
  | .resources[]
  | select(.type == "databricks_service_principal")
  | .values.id
'
```

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `application_id` | `string` | yes | — | Entra ID client/application ID of the service principal. |
| `databricks_workspace_ids` | `set(string)` | yes | — | One or more numeric Databricks workspace IDs to assign the SP to. |
| `workspace_permission` | `string` | no | `"USER"` | Default workspace-level role (`USER` or `ADMIN`) for workspaces not listed in `workspace_permission_overrides`. |
| `workspace_permission_overrides` | `map(string)` | no | `{}` | Per-workspace role overrides, keyed by workspace ID as a string. Values must be `USER` or `ADMIN`. |
| `create_databricks_service_principal` | `bool` | no | `false` | If `true`, register the Entra application as a Databricks account-level SP instead of looking up a pre-existing one. The Entra application must still already exist; no `azuread` provider is used. |
| `display_name` | `string` | no | `"HiddenLayer Autoscan"` | Display name applied when `create_databricks_service_principal` is `true`; not used for lookup. |

## Outputs

| Name | Description |
|------|-------------|
| `application_id` | The Entra ID application ID — pass to the root module's `run_as_service_principal_application_id`. |
| `service_principal_id` | Internal Databricks principal ID (distinct from `application_id`). |

## Provider aliases

| Alias | Used for |
|-------|----------|
| `databricks.account` | `data.databricks_service_principal` lookup and `databricks_mws_permission_assignment` — must target `https://accounts.azuredatabricks.net`. |
