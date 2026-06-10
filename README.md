# terraform-databricks-hiddenlayer-autoscan

Terraform module that deploys the [HiddenLayer Databricks Model Scanner](https://github.com/hiddenlayerai/hiddenlayer-databricks-model-scanner):
it uploads the scanner notebooks, stores HiddenLayer credentials,
and creates the **scheduled job** that polls Unity Catalog for new model versions
and submits them to the HiddenLayer Model Scanner.

This is the declarative equivalent of the `hldbx autoscan` CLI, intended for teams
that manage their Databricks infrastructure with Terraform across multiple
workspaces and accounts.

## What it creates


| Resource                                                                | Purpose                                                                      |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `databricks_directory`                                                  | Versioned workspace folder `/<base>/<notebook_version>`                      |
| `databricks_notebook` x3                                                | `hl_monitor_models`, `hl_scan_model`, `hl_test`                              |
| `databricks_workspace_file`                                             | `hl_common.py` (plain module, imported by the notebooks)                     |
| `databricks_secret_scope` / `databricks_secret`                         | HiddenLayer `client_id:client_secret` per `catalog.schema` (SaaS only)       |
| `databricks_job`                                                        | The cron-scheduled monitor job (the centerpiece)                             |
| `databricks_secret_acl` / `databricks_permissions` / `databricks_grant` | Permissions the run-as service principal needs to run and to spawn scan jobs |


The per-model **scan jobs are created at runtime** by the monitor notebook and are
intentionally *not* managed by Terraform.

## Usage

```hcl
provider "databricks" {
  host = "https://adb-1234567890123456.7.azuredatabricks.net"
}

module "hl_autoscan" {
  source  = "hiddenlayerai/hiddenlayer-autoscan/databricks"
  version = "~> 0.1"

  cluster_id = "1234-567890-abcde123"
  schemas    = [{ catalog = "production_catalog", schema = "models" }]

  run_as_service_principal_application_id = "11111111-2222-3333-4444-555555555555"

  # SaaS credentials are separate sensitive variables so they don't taint
  # the non-sensitive URL config used for for_each key derivation.
  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret

  # Optional: override endpoint URLs (defaults target the US SaaS region).
  # hiddenlayer = { api_url = "https://api.eu.hiddenlayer.ai", ... }

  quartz_cron = "0 0 */12 * * ?"
}
```

See `[examples/](./examples)` for single- and multi-workspace setups.

## How the job gets scheduled

There is no external scheduler. The `databricks_job` carries a `schedule` block
with your Quartz cron expression, and the **Databricks Jobs scheduler** fires it.
After `terraform apply` the job exists and (unless `pause_status = "PAUSED"`) runs
on the cron with no further action.

## SaaS vs Enterprise scanner

If `hiddenlayer.api_url` does **not** end in `.hiddenlayer.ai`, the module treats
it as an Enterprise (self-hosted) scanner: no secret scope/secret is created and
`hiddenlayer_client_id`/`hiddenlayer_client_secret` are not required. This mirrors
`Config.UsesEnterpriseModelScanner()` in the CLI.

## Run-as permissions (important)

For an unattended job, set `run_as_service_principal_application_id`. With
`manage_permissions`/`manage_uc_grants` enabled (default), the module grants that
SP:

- `READ` on each HiddenLayer secret scope,
- cluster access (`cluster_permission_level`, default `CAN_RESTART`) and
`CAN_MANAGE_RUN` on the job,
- Unity Catalog `USE_CATALOG`, `USE_SCHEMA`, `EXECUTE`, `APPLY_TAG`.

The SP must also be able to create jobs in the workspace, because the monitor
notebook spawns scan jobs at runtime. Disable the grant management if your
Terraform principal cannot manage UC grants and handle those out-of-band.

## Multi-workspace / multi-account

The core module is workspace-scoped and cloud-agnostic. Pass an aliased provider
per workspace via the `providers` meta-argument (see the multi-workspace example).

The optional `[modules/identity-azure](./modules/identity-azure)` submodule handles
the cloud-specific part for Azure: given a pre-existing Entra ID-backed service
principal it looks the SP up at the Databricks account level and assigns it to one
or more workspaces via a single module call, then outputs the `application_id` for
the root module's `run_as_service_principal_application_id`. Use it when you want
Terraform to own the workspace-assignment step; skip it and pass `application_id`
directly if that assignment is managed elsewhere.

## Notebook source of truth

The notebooks in `[notebooks/](./notebooks)` are vendored from
`hiddenlayerai/hiddenlayer-databricks-model-scanner` and pinned in
`notebooks/.upstream-version`. The `notebook-drift` workflow fails if they drift,
and the upstream repo opens a sync PR here on each release.

## Inputs

See `[variables.tf](./variables.tf)` for the full list. Required: `cluster_id`,
`schemas`.

## Limitations

- HiddenLayer credentials are stored in Terraform state via `databricks_secret`;  
protect your state backend (or use an Azure Key Vault-backed scope variant).

