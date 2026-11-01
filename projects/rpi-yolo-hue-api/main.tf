locals {
  project_name = "rpi-yolo-hue-api"
  environment  = "dev"
  region_code  = "neu"
  instance     = "01"
  container    = "images"

  # Storage account names allow only lowercase letters and numbers and have a
  # 24-character limit. Preserve the type, environment, region, and instance
  # components by truncating only the normalized project component.
  normalized_project_name       = replace(lower(local.project_name), "/[^0-9a-z]/", "")
  storage_account_suffix        = "${local.environment}${local.region_code}${local.instance}"
  storage_project_name_max_size = 24 - length("st") - length(local.storage_account_suffix)
  storage_project_name          = substr(local.normalized_project_name, 0, local.storage_project_name_max_size)
  storage_account_name          = "st${local.storage_project_name}${local.storage_account_suffix}"

  # Key Vault names are globally unique and limited to 24 characters. As with
  # the storage account, truncate only the project component when necessary.
  key_vault_suffix                = "${local.environment}${local.region_code}${local.instance}"
  key_vault_project_name_max_size = 24 - length("kv") - length(local.key_vault_suffix)
  key_vault_project_name          = substr(local.normalized_project_name, 0, local.key_vault_project_name_max_size)
  key_vault_name                  = "kv${local.key_vault_project_name}${local.key_vault_suffix}"

  machine_learning_workspace_name = "mlw-${local.project_name}-${local.environment}-${local.region_code}-${local.instance}"
  application_insights_name       = "appi-${local.project_name}-${local.environment}-${local.region_code}-${local.instance}"
  log_analytics_workspace_name    = "log-${local.project_name}-${local.environment}-${local.region_code}-${local.instance}"

  common_tags = {
    project     = local.project_name
    environment = local.environment
    managed_by  = "terraform"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "project" {
  name     = "rg-${local.project_name}-${local.environment}-${local.region_code}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "images" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  public_network_access             = "Enabled"
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = true
  default_to_oauth_authentication   = true
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true

  local_user_enabled = false
  sftp_enabled       = false
  nfsv3_enabled      = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days                     = var.soft_delete_retention_days
      permanent_delete_enabled = false
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "images" {
  name                  = local.container
  storage_account_id    = azurerm_storage_account.images.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "images_data_owner" {
  scope                = azurerm_storage_container.images.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.owner_principal_id
  principal_type       = "User"
}

resource "azurerm_storage_management_policy" "images" {
  storage_account_id = azurerm_storage_account.images.id

  rule {
    name    = "delete-old-image-versions"
    enabled = true

    filters {
      prefix_match = ["${local.container}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = var.old_version_retention_days
      }
    }
  }
}

resource "azurerm_log_analytics_workspace" "machine_learning" {
  name                = local.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = local.common_tags
}

resource "azurerm_application_insights" "machine_learning" {
  name                = local.application_insights_name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.machine_learning.id

  tags = local.common_tags
}

resource "azurerm_key_vault" "machine_learning" {
  name                = local.key_vault_name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  public_network_access_enabled = true

  tags = local.common_tags
}

resource "azurerm_machine_learning_workspace" "project" {
  name                = local.machine_learning_workspace_name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location

  application_insights_id = azurerm_application_insights.machine_learning.id
  key_vault_id            = azurerm_key_vault.machine_learning.id
  storage_account_id      = azurerm_storage_account.images.id

  friendly_name                 = "Raspberry Pi YOLO Hue API"
  description                   = "Model development workspace for the rpi-yolo-hue-api project."
  sku_name                      = "Basic"
  public_network_access_enabled = true
  v1_legacy_mode_enabled        = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

moved {
  from = azurerm_role_assignment.machine_learning_contributor
  to   = azurerm_role_assignment.project_owner
}

resource "azurerm_role_assignment" "project_owner" {
  scope                = azurerm_resource_group.project.id
  role_definition_name = "Owner"
  principal_id         = var.owner_principal_id
  principal_type       = "User"

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_role_assignment" "project_support_request_contributor" {
  scope                = azurerm_resource_group.project.id
  role_definition_name = "Support Request Contributor"
  principal_id         = var.owner_principal_id
  principal_type       = "User"
}

