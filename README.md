# terraform-databricks-hiddenlayer-autoscan

Terraform module that deploys the [HiddenLayer Databricks Model Scanner](https://github.com/hiddenlayerai/hiddenlayer-databricks-model-scanner):
it uploads the scanner notebooks, stores HiddenLayer credentials,
and creates the **scheduled job** that polls Unity Catalog for new model versions
and submits them to the HiddenLayer Model Scanner.

This is the declarative equivalent of the `hldbx autoscan` CLI, intended for teams
that manage their Databricks infrastructure with Terraform across multiple
workspaces and accounts.

The core module is **cloud-agnostic** and works against Databricks on AWS, Azure,
or GCP — it only talks to a Databricks workspace (and, for `run_as`, an existing
Databricks service principal), never to a cloud provider's APIs directly. The only
cloud-specific piece is the optional `[modules/identity-azure](./modules/identity-azure)`
submodule; AWS and GCP users wire up the run-as service principal with their own
identity tooling and pass its `application_id` in (see
[Multi-workspace / multi-account](#multi-workspace--multi-account)).

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
# The module is cloud-agnostic; point the provider at any Databricks workspace:
#   AWS:   https://dbc-1234abcd-5678.cloud.databricks.com
#   Azure: https://adb-1234567890123456.7.azuredatabricks.net
#   GCP:   https://1234567890123456.7.gcp.databricks.com
provider "databricks" {
  host = "https://dbc-1234abcd-5678.cloud.databricks.com"
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
per workspace via the `providers` meta-argument (see the examples below).

### Run-as identity by cloud

The root module only needs the `application_id` of an existing Databricks service
principal in `run_as_service_principal_application_id`; how that SP is created and
assigned to a workspace is cloud-specific and **outside** the core module:

- **AWS / GCP** — create the Databricks service principal (and its workspace
assignment) with the Databricks Terraform provider directly
(`databricks_service_principal` + `databricks_mws_permission_assignment`), the
account console, or the CLI, then pass its `application_id` to the root module.
There is no cloud identity provider to federate; the SP is Databricks-managed.
- **Azure** — use one of the two Azure submodules described below.

### Azure submodules

#### `modules/autoscan-azure` — recommended for Azure (one module call per workspace)

The [`modules/autoscan-azure`](./modules/autoscan-azure) wrapper combines
identity wiring and autoscan deployment into a single module call per workspace.
It requires two Databricks provider aliases — `databricks.account` (shared) and
`databricks.workspace` (one per workspace):

```hcl
module "hl_workspace_a" {
  source = "git@github.com:hiddenlayerai/terraform-databricks-hiddenlayer-autoscan.git//modules/autoscan-azure?ref=main"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace_a
  }

  application_id                      = var.run_as_sp_application_id
  workspace_id                        = "1234567890123456"
  create_databricks_service_principal = true   # set true once; false for all other workspaces

  cluster_id                = var.cluster_id
  schemas                   = var.schemas
  hiddenlayer_client_id     = var.hl_client_id
  hiddenlayer_client_secret = var.hl_client_secret
}
```

See [`modules/autoscan-azure/README.md`](./modules/autoscan-azure/README.md) for
the full input/output reference.

#### `modules/identity-azure` — lower-level Azure identity wiring

The [`modules/identity-azure`](./modules/identity-azure) submodule handles only
the identity layer: given an Entra ID-backed service principal it wires that SP
into one or more workspaces via a single module call, then outputs the
`application_id` for the root module's `run_as_service_principal_application_id`.
Use it directly when you need to separate identity management from deployment, or
when you are using the root module without the `autoscan-azure` wrapper.

### Creating vs. looking up the service principal (Azure)

The Azure submodules deal with two distinct identity layers:

1. **Entra (Azure AD) application** — the underlying identity in Microsoft Entra
ID. Neither submodule **ever** creates this; it must already exist, and no
`azuread` provider is involved.
2. **Databricks account-level service principal** — the Databricks-side record
that references the Entra application by `application_id`. Set
`create_databricks_service_principal = true` to register it, or leave the default
(`false`) to look up a pre-existing SP (registered via the account console, CLI,
or another Terraform config).

When deploying to multiple workspaces, only **one** module should have
`create_databricks_service_principal = true` — this registers the SP in the
Databricks account once. All other workspace modules should use the default
`false` to look up the already-registered SP.

The Entra **application ID** (a GUID) is the value used everywhere for Azure SPs
— it is the `application_id` input to the submodule, the `application_id` it
outputs, and what the root module expects in
`run_as_service_principal_application_id`.

### Deploying to many workspaces

| Workspace count | Recommended pattern |
|---|---|
| 1 | [`examples/single-workspace`](./examples/single-workspace) |
| 2–5 | [`examples/multi-workspace`](./examples/multi-workspace) — one module block per workspace |
| 5+ | [`examples/ci-matrix`](./examples/ci-matrix) — one Terraform apply per workspace via a CI matrix job |

The CI matrix pattern in [`examples/ci-matrix`](./examples/ci-matrix) uses a
single parameterized Terraform root driven by per-workspace `.tfvars` files. A
GitHub Actions matrix runs `terraform apply -var-file=<workspace>.tfvars` for
each workspace in parallel, each with its own isolated Terraform state. This
avoids unbounded growth of provider/module blocks in a single root config and
gives each workspace an independent blast radius.

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
protect your state backend. On Azure you can instead back the scope with Azure Key
Vault; AWS and GCP only support Databricks-backed secret scopes, so manage state
access carefully there.

