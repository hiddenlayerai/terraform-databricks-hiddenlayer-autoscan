terraform {
  required_version = ">= 1.5"

  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = ">= 1.40"
      configuration_aliases = [databricks.account, databricks.workspace]
    }
  }
}
