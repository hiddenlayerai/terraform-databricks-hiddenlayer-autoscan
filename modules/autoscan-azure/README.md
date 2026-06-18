# autoscan-azure

Azure convenience wrapper that combines
[`identity-azure`](../identity-azure) and the
[root autoscan module](../../) into **one module call per workspace**.

It accepts two Databricks provider aliases — `databricks.account` (shared across
all workspaces) and `databricks.workspace` (one per workspace) — and handles the
full deployment internally:

1. Registers or looks up the Entra ID-backed service principal in the Databricks
   account (`identity-azure`).
2. Assigns the SP to the target workspace and grants workspace admins `CAN_USE`
   (`identity-azure`).
3. Uploads the HiddenLayer notebooks and creates the scheduled monitor job,
   wiring the SP as the `run_as` identity (root module).

## When to use this vs. the individual modules

| Scenario | Recommendation |
|---|---|
| Azure, single workspace | This wrapper — one module call, no wiring required |
| Azure, multiple workspaces | This wrapper once per workspace (see Multi-workspace below) |
| AWS / GCP | Use the root module directly; wire your SP via `run_as_service_principal_application_id` |
| Need fine-grained control over identity vs. deployment separately | Use `identity-azure` + root module individually |

## Usage

```hcl
provider "databricks" {
  alias               = "account"
  host                = "https://accounts.azuredatabricks.net"
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

provider "databricks" {
  alias               = "my_workspace"
  host                = "https://adb-1234567890123456.7.azuredatabricks.net"
  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
}

module "hl" {
  source = "git@github.com:hiddenlayerai/terraform-databricks-hiddenlayer-autoscan.git//modules/autoscan-azure?ref=main"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.my_workspace
  }

  application_id                      = "11111111-2222-3333-4444-555555555555"
  workspace_id                        = "1234567890123456"
  create_databricks_service_principal = true   # false if already registered

  cluster_id = "1234-567890-abcde123"
  schemas    = [{ catalog = "production_catalog", schema = "models" }]

  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret
}
```

## Multi-workspace

Instantiate the module once per workspace, each with its own workspace provider
alias and the same `databricks.account` provider. Only set
`create_databricks_service_principal = true` in **one** workspace module — the
first one registers the SP in the Databricks account; all others should use
`false` to look it up:

```hcl
module "hl_workspace_a" {
  source    = "...//modules/autoscan-azure"
  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace_a
  }
  application_id                      = var.run_as_sp_application_id
  workspace_id                        = "111111111111111"
  create_databricks_service_principal = true   # registers the SP once
  cluster_id                          = var.workspace_a_cluster_id
  schemas                             = var.workspace_a_schemas
  hiddenlayer_client_id               = var.hl_client_id
  hiddenlayer_client_secret           = var.hl_client_secret
}

module "hl_workspace_b" {
  source    = "...//modules/autoscan-azure"
  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace_b
  }
  application_id                      = var.run_as_sp_application_id
  workspace_id                        = "222222222222222"
  create_databricks_service_principal = false  # SP already registered above
  cluster_id                          = var.workspace_b_cluster_id
  schemas                             = var.workspace_b_schemas
  hiddenlayer_client_id               = var.hl_client_id
  hiddenlayer_client_secret           = var.hl_client_secret
}
```

For larger workspace fleets, prefer the CI matrix approach in
[`examples/ci-matrix`](../../examples/ci-matrix) — one Terraform apply per
workspace, each with its own state and tfvars file.

## Provider aliases

| Alias | Required for |
|---|---|
| `databricks.account` | Account-level SP registration and workspace assignment |
| `databricks.workspace` | SP `CAN_USE` permission, notebook upload, job creation |

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `application_id` | `string` | yes | — | Entra ID application (client) ID of the run-as SP. |
| `workspace_id` | `string` | yes | — | Numeric Databricks workspace ID. |
| `cluster_id` | `string` | yes | — | Cluster ID for the monitor job. |
| `schemas` | `list(object)` | yes | — | `catalog`/`schema` pairs to monitor. |
| `create_databricks_service_principal` | `bool` | no | `false` | Register the SP in the Databricks account (set `true` once per SP). |
| `display_name` | `string` | no | `null` | Display name when creating the SP. |
| `workspace_permission` | `string` | no | `"ADMIN"` | Workspace role for the SP (`USER` or `ADMIN`). `ADMIN` is required for the SP to read MLflow training-run artifacts owned by other workspace users — see [MLflow experiment permissions](#mlflow-experiment-permissions) below. |
| `hiddenlayer` | `object` | no | `{}` | HiddenLayer endpoint URLs. |
| `hiddenlayer_client_id` | `string` | no | `null` | HiddenLayer API client ID (SaaS only). |
| `hiddenlayer_client_secret` | `string` | no | `null` | HiddenLayer API client secret (SaaS only). |
| `job_name` | `string` | no | `"hl_find_new_model_versions"` | Monitor job name. |
| `quartz_cron` | `string` | no | `"0 0 */12 * * ?"` | Polling schedule. |
| `pause_status` | `string` | no | `"UNPAUSED"` | `PAUSED` or `UNPAUSED`. |
| `manage_permissions` | `bool` | no | `true` | Grant the SP cluster/job permissions. |
| `manage_uc_grants` | `bool` | no | `true` | Grant the SP Unity Catalog privileges. |

## Outputs

| Name | Description |
|---|---|
| `job_url` | Workspace URL of the scheduled monitor job. |
| `job_id` | Databricks job ID. |
| `workspace_directory` | Workspace path where notebooks were uploaded. |
| `application_id` | Entra ID application ID of the run-as SP. |
| `service_principal_id` | Internal Databricks principal ID of the run-as SP. |

## MLflow experiment permissions

When a `run_as` SP is set, scan jobs run as that SP rather than as the
workspace-admin job owner. The SP needs to read the MLflow training run whose
artifacts it is scanning. Training runs live in experiments owned by the model's
author, not by the SP.

The default `workspace_permission = "ADMIN"` provides the necessary access. If
you have explicitly overridden to `"USER"` and encounter this error, restore the
default or see the [`identity-azure` README](../identity-azure#mlflow-experiment-permissions)
for manual per-experiment remediation steps.
