provider "azurerm" {
  features {}
}

# service principals
data "azuread_client_config" "current" {}

data "azuread_service_principal" "vault" {
  display_name = "bradfordwagner-vault"
}

# resource group for all infrastructure to be added to
resource "azurerm_resource_group" "vault" {
  name     = "bradfordwagner-vault"
  location = "eastus2"
}

resource "azurerm_key_vault" "vault" {
  name                = "bradfordwagner-vault"
  location            = azurerm_resource_group.vault.location
  resource_group_name = azurerm_resource_group.vault.name
  tenant_id           = data.azuread_client_config.current.tenant_id

  # enable virtual machines to access this key vault.
  # NB this identity is used in the example /tmp/azure_auth.sh file.
  #    vault is actually using the vault service principal.
  enabled_for_deployment = true

  sku_name = "standard"

  # access policy for the hashicorp vault service principal.
  access_policy {
    tenant_id = data.azuread_service_principal.vault.application_tenant_id
    object_id = data.azuread_service_principal.vault.object_id

    key_permissions = [
      "Get",
      "WrapKey",
      "UnwrapKey",
    ]
  }

  # access policy for the user that is currently running terraform.
  access_policy {
    tenant_id = data.azuread_client_config.current.tenant_id
    object_id = data.azuread_client_config.current.object_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update",
      "Purge",
      "Recover",
    ]
  }

  # TODO does this really need to be so broad? can it be limited to the vault vm?
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# TODO the "generated" resource name is not very descriptive; why not use "vault" instead?
# hashicorp vault will use this azurerm_key_vault_key to wrap/encrypt its master key.
resource "azurerm_key_vault_key" "generated" {
  name         = "generated-key"
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "wrapKey",
    "unwrapKey",
  ]
}

# setup storage account
resource "azurerm_storage_account" "vault_blob" {
  name                      = "bradfordwagnervault"
  account_tier              = "Standard"
  account_kind              = "BlobStorage"
  account_replication_type  = "GRS"
  resource_group_name       = azurerm_resource_group.vault.name
  location                  = azurerm_resource_group.vault.location
  shared_access_key_enabled = true
}

