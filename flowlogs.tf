resource "azurerm_storage_account" "flowlogs" {
  name                     = "flowlogsstg${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.hub-vnet-rg.name
  location                 = azurerm_resource_group.hub-vnet-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


