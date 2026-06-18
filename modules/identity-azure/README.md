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
  databricks_workspace_ids = [123456789012345]  # add more IDs for multi-workspace

  # Optional: register the Databricks account-level SP instead of looking it up.
  # create_databricks_service_principal = true

  # Optional: override the role for specific workspaces (keyed by workspace ID).
  # workspace_permission_overrides = { "123456789012345" = "ADMIN" }
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
| `application_id` | `string` | yes | — | Entra ID client/application ID of the service principal. |
| `databricks_workspace_ids` | `set(number)` | yes | — | One or more numeric Databricks workspace IDs to assign the SP to. |
| `workspace_permission` | `string` | no | `"USER"` | Default workspace-level role (`USER` or `ADMIN`) for workspaces not listed in `workspace_permission_overrides`. |
| `workspace_permission_overrides` | `map(string)` | no | `{}` | Per-workspace role overrides, keyed by workspace ID as a string. Values must be `USER` or `ADMIN`. |
| `create_databricks_service_principal` | `bool` | no | `false` | If `true`, register the Entra application as a Databricks account-level SP instead of looking up a pre-existing one. The Entra application must still already exist; no `azuread` provider is used. |
| `display_name` | `string` | no | `null` | Display name applied when `create_databricks_service_principal` is `true`; not used for lookup. |

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
