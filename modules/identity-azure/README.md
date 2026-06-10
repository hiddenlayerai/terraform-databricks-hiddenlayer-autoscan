# identity-azure

Optional submodule that wires a **pre-existing** Entra ID-backed Databricks
service principal into a target workspace so the HiddenLayer root module can
use it as the `run_as` identity for the scheduled monitor job.

The submodule does **not** create an Entra ID application or Databricks service
principal — it looks up the existing SP by `application_id` at the account
level and ensures it has workspace access via `databricks_mws_permission_assignment`.

## Prerequisites

- An Azure Entra ID application / service principal already created.
- That application registered as a Databricks account-level service principal
  (via the Databricks account console, the CLI, or another Terraform config).
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
    databricks.account   = databricks.account
    databricks.workspace = databricks
  }

  application_id          = "00000000-0000-0000-0000-000000000000"
  databricks_workspace_id = 123456789012345
}

module "hiddenlayer" {
  source = "path/to/terraform-databricks-hiddenlayer-autoscan"

  run_as_service_principal_application_id = module.hl_identity.application_id

  cluster_id  = var.cluster_id
  schemas     = var.schemas
  hiddenlayer = { api_url = "https://api.us.hiddenlayer.ai" }
}
```

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `application_id` | `string` | yes | — | Entra ID client/application ID of the pre-existing service principal. |
| `databricks_workspace_id` | `number` | yes | — | Numeric Databricks workspace ID used to bind the SP to the workspace. |
| `workspace_permission` | `string` | no | `"USER"` | Workspace-level role (`USER` or `ADMIN`). |
| `display_name` | `string` | no | `null` | Informational display name; not used for lookup. |

## Outputs

| Name | Description |
|------|-------------|
| `application_id` | The Entra ID application ID — pass to the root module's `run_as_service_principal_application_id`. |
| `service_principal_id` | Internal Databricks principal ID (distinct from `application_id`). |

## Provider aliases

This submodule declares two `databricks` provider aliases:

| Alias | Used for |
|-------|----------|
| `databricks.account` | `data.databricks_service_principal` lookup and `databricks_mws_permission_assignment` — must target `https://accounts.azuredatabricks.net`. |
| `databricks.workspace` | Reserved for future workspace-scoped resources; pass your workspace-scoped `databricks` provider here. |
