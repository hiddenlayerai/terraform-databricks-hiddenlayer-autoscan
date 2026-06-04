# identity-azure (placeholder - Phase 3)

Optional submodule for **creating** the run-as service principal on Azure
(Entra ID application + service principal, registered into the Databricks
account) so the root module can consume its `application_id`.

This is intentionally not implemented yet. The core module currently expects you
to pass an existing service principal via
`run_as_service_principal_application_id`. Equivalent `identity-aws` and
`identity-gcp` submodules will follow.
