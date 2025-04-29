locals {
  spoke2-location       = "australiaeast"
  spoke2-resource-group = "spoke2-vnet-rg-${random_string.suffix.result}"
  prefix-spoke2         = "spoke2"
}

resource "azurerm_resource_group" "spoke2-vnet-rg" {
  name     = local.spoke2-resource-group
  location = local.spoke2-location
}

resource "azurerm_virtual_network" "spoke2-vnet" {
  name                = "${local.prefix-spoke2}-vnet"
  location            = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name
  address_space       = ["10.2.0.0/16"]

  tags = {
     environment = local.prefix-spoke2
  }
}

resource "azurerm_subnet" "spoke2-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.0.64/27"]
}

resource "azurerm_subnet" "spoke2-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_virtual_network_peering" "spoke2-hub-peer" {
  name                      = "${local.prefix-spoke2}-hub-peer"
  resource_group_name       = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on                   = [azurerm_virtual_network.spoke2-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

resource "azurerm_network_interface" "spoke2-nic" {
  name                 = "${local.prefix-spoke2}-nic"
  location             = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = local.prefix-spoke2
    subnet_id                     = azurerm_subnet.spoke2-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.prefix-spoke2
  }
}

resource "azurerm_virtual_machine" "spoke2-vm" {
  name                  = "${local.prefix-spoke2}-vm"
  location              = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name   = azurerm_resource_group.spoke2-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.spoke2-nic.id]
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
    computer_name  = "${local.prefix-spoke2}-vm"
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    "application" = "Procurement"
    "Role"        = "Processing"
    environment = local.prefix-spoke2
  }
}

resource "azurerm_virtual_network_peering" "hub-spoke2-peer" {
  name                         = "hub-spoke2-peer"
  resource_group_name          = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.spoke2-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}
resource "azurerm_route_table" "spoke2-fw-rt" {
  name                = "spoke2-fw-rt"
  location            = local.spoke2-location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name
}

resource "azurerm_route" "spoke2-fw-default" {
  name                    = "default-to-fw"
  resource_group_name     = azurerm_resource_group.spoke2-vnet-rg.name
  route_table_name        = azurerm_route_table.spoke2-fw-rt.name
  address_prefix          = "0.0.0.0/0"
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address  = azurerm_firewall.hub-firewall.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "spoke2-mgmt-rt-assoc" {
  subnet_id      = azurerm_subnet.spoke2-mgmt.id
  route_table_id = azurerm_route_table.spoke2-fw-rt.id
}

resource "azurerm_subnet_route_table_association" "spoke2-workload-rt-assoc" {
  subnet_id      = azurerm_subnet.spoke2-workload.id
  route_table_id = azurerm_route_table.spoke2-fw-rt.id
}

resource "azurerm_network_security_group" "spoke2-nsg" {
  name                = "${local.prefix-spoke2}-nsg"
  location            = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internet-Outbound"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = {
    environment = local.prefix-spoke2
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke2-mgmt-nsg-assoc" {
  subnet_id                 = azurerm_subnet.spoke2-mgmt.id
  network_security_group_id = azurerm_network_security_group.spoke2-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "spoke2-workload-nsg-assoc" {
  subnet_id                 = azurerm_subnet.spoke2-workload.id
  network_security_group_id = azurerm_network_security_group.spoke2-nsg.id
}

# SQL Server
resource "azurerm_mssql_server" "spoke2-sql-server" {
  name                         = "${local.prefix-spoke2}-sqlserver"
  resource_group_name          = azurerm_resource_group.spoke2-vnet-rg.name
  location                     = local.spoke2-location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = "ReplaceWithSecurePassword123!" # Use var or Key Vault in production

  tags = {
    "application" = "Procurement"
    "Role"        = "Database"
    environment = local.prefix-spoke2
  }
}

# SQL Database
resource "azurerm_mssql_database" "spoke2-sqldb" {
  name           = "${local.prefix-spoke2}-sqldb"
  server_id      = azurerm_mssql_server.spoke2-sql-server.id
  sku_name       = "Basic"
  max_size_gb    = 2
  zone_redundant = false

  tags = {
    "application" = "Procurement"
    "Role"        = "Database"
    environment = local.prefix-spoke2
  }
}

# Private DNS Zone for SQL
resource "azurerm_private_dns_zone" "sql-dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name
}

# Link DNS Zone to Spoke2 VNet
resource "azurerm_private_dns_zone_virtual_network_link" "sql-dns-link" {
  name                  = "${local.prefix-spoke2}-sql-dns-link"
  resource_group_name   = azurerm_resource_group.spoke2-vnet-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql-dns.name
  virtual_network_id    = azurerm_virtual_network.spoke2-vnet.id
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql-private-endpoint" {
  name                = "${local.prefix-spoke2}-sql-pe"
  location            = local.spoke2-location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name
  subnet_id           = azurerm_subnet.spoke2-mgmt.id

  private_service_connection {
    name                           = "${local.prefix-spoke2}-sql-priv-conn"
    private_connection_resource_id = azurerm_mssql_server.spoke2-sql-server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql-dns.id]
  }

  tags = {
    environment = local.prefix-spoke2
  }
}
output "sql_private_endpoint_ip" {
  value = azurerm_private_endpoint.sql-private-endpoint.private_service_connection[0].private_ip_address
}
