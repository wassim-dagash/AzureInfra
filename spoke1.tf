locals {
  spoke1-location       = "australiaeast"
  spoke1-resource-group = "spoke1-vnet-rg-${random_string.suffix.result}"
  prefix-spoke1         = "spoke1"
}

resource "azurerm_resource_group" "spoke1-vnet-rg" {
  name     = local.spoke1-resource-group
  location = local.spoke1-location
}

resource "azurerm_virtual_network" "spoke1-vnet" {
  name                = "spoke1-vnet"
  location            = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = local.prefix-spoke1
  }
}

resource "azurerm_subnet" "spoke1-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.0.64/27"]
}

resource "azurerm_subnet" "spoke1-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_virtual_network_peering" "spoke1-hub-peer" {
  name                      = "spoke1-hub-peer"
  resource_group_name       = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke1-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on                   = [azurerm_virtual_network.spoke1-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

resource "azurerm_network_interface" "spoke1-nic" {
  name                 = "${local.prefix-spoke1}-nic"
  location             = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = local.prefix-spoke1
    subnet_id                     = azurerm_subnet.spoke1-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "spoke1-vm" {
  name                  = "${local.prefix-spoke1}-vm"
  location              = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name   = azurerm_resource_group.spoke1-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.spoke1-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }


  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.prefix-spoke1}-vm"
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-spoke1
    "application" = "Finance"
    "Role"        = "Processing"
  }
}

resource "azurerm_virtual_network_peering" "hub-spoke1-peer" {
  name                         = "hub-spoke1-peer"
  resource_group_name          = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.spoke1-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

resource "azurerm_route_table" "spoke1-fw-rt" {
  name                = "spoke1-fw-rt"
  location            = local.spoke1-location
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
}

resource "azurerm_route" "spoke1-fw-default" {
  name                    = "default-to-fw"
  resource_group_name     = azurerm_resource_group.spoke1-vnet-rg.name
  route_table_name        = azurerm_route_table.spoke1-fw-rt.name
  address_prefix          = "0.0.0.0/0" # All internet traffic goes through the firewall
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address  = azurerm_firewall.hub-firewall.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke1-to-hub-via-fw" {
  name                    = "to-hub-via-fw"
  resource_group_name     = azurerm_resource_group.spoke1-vnet-rg.name
  route_table_name        = azurerm_route_table.spoke1-fw-rt.name
  address_prefix          = "10.0.0.0/16"  # All Internal traffic goes through the firewall
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address  = azurerm_firewall.hub-firewall.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "spoke1-mgmt-rt-assoc" {
  subnet_id      = azurerm_subnet.spoke1-mgmt.id
  route_table_id = azurerm_route_table.spoke1-fw-rt.id
}

resource "azurerm_subnet_route_table_association" "spoke1-workload-rt-assoc" {
  subnet_id      = azurerm_subnet.spoke1-workload.id
  route_table_id = azurerm_route_table.spoke1-fw-rt.id
}

# SQL Server
resource "azurerm_mssql_server" "spoke1-sql-server" {
  name                         = "${local.prefix-spoke1}-sqlserver"
  resource_group_name          = azurerm_resource_group.spoke1-vnet-rg.name
  location                     = local.spoke1-location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = "ReplaceWithSecurePassword123!" # Secure this

  tags = {
    "application" = "Finance"
    "Role"        = "Database"
    environment = local.prefix-spoke1
  }
}

# SQL Database
resource "azurerm_mssql_database" "spoke1-sqldb" {
  name           = "${local.prefix-spoke1}-sqldb"
  server_id      = azurerm_mssql_server.spoke1-sql-server.id
  sku_name       = "Basic"
  max_size_gb    = 2
  zone_redundant = false

  tags = {
    "application" = "Finance"
    "Role"        = "Database"
    environment = local.prefix-spoke1
  }
}

# Private DNS Zone (reuse if already created in hub/shared setup, otherwise recreate here)
resource "azurerm_private_dns_zone" "sql-dns-spoke1" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
}

# Link DNS Zone to Spoke1 VNet
resource "azurerm_private_dns_zone_virtual_network_link" "sql-dns-link-spoke1" {
  name                  = "${local.prefix-spoke1}-sql-dns-link"
  resource_group_name   = azurerm_resource_group.spoke1-vnet-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql-dns-spoke1.name
  virtual_network_id    = azurerm_virtual_network.spoke1-vnet.id
}

# Private Endpoint in Spoke1
resource "azurerm_private_endpoint" "sql-private-endpoint-spoke1" {
  name                = "${local.prefix-spoke1}-sql-pe"
  location            = local.spoke1-location
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
  subnet_id           = azurerm_subnet.spoke1-mgmt.id

  private_service_connection {
    name                           = "${local.prefix-spoke1}-sql-priv-conn"
    private_connection_resource_id = azurerm_mssql_server.spoke1-sql-server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql-dns.id]
  }

  tags = {
    environment = local.prefix-spoke1
  }
}

# Optional output: Private IP of the endpoint
output "sql_private_endpoint_ip_spoke1" {
  value = azurerm_private_endpoint.sql-private-endpoint-spoke1.private_service_connection[0].private_ip_address
}

