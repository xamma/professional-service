# Copyright 2026 Schwarz Digits Cloud GmbH & Co. KG
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# STACKIT Side (vpn-sna-01)
module "vpn_sna_01" {
  source                    = "../module/stackit-sna-with-debug-machine"
  machine_availability_zone = "eu01-1"
  machine_ipv4_prefix       = "10.10.10.0/24"
  machine_network_name      = "vpn-sna-01"
  sna_name                  = "vpn-sna-01"
  machine_name              = "vpn-sna-01"
  stackit_admin_email       = var.stackit_admin_email
  stackit_org_id            = var.stackit_org_id
  stackit_project_name      = "vpn-sna-01"
  sna_network_range_prefix = [
    "10.10.0.0/16"
  ]
}

resource "restful_resource" "vpn_01_gateway" {
  provider = restful.stackit
  path     = "/v1/projects/${module.vpn_sna_01.project_id}/regions/eu01/gateways"
  body = {
    availabilityZones = {
      tunnel1 = "eu01-1"
      tunnel2 = "eu01-2"
    }
    bgp = {
      localAsn                 = 64512
      overrideAdvertisedRoutes = ["10.10.0.0/16"]
    }
    displayName = "vpn01"
    labels      = null
    planId      = "p500"
    routingType = "BGP_ROUTE_BASED"
  }

  read_path     = "$(path)/$(body.id)"
  update_path   = "$(path)/$(body.id)"
  update_method = "PUT"
  delete_path   = "$(path)/$(body.id)"
  delete_method = "DELETE"
}

data "restful_resource" "vpn_01_gateway_status" {
  provider = restful.stackit
  id       = "${restful_resource.vpn_01_gateway.id}/status"
}

resource "random_password" "vpn_psk" {
  length  = 32
  special = false
}

# Azure Side
resource "azurerm_resource_group" "rg" {
  name     = "rg-vpn-test"
  location = "West Europe"
}

# 1. Azure VNet and Subnets
resource "azurerm_virtual_network" "azure_vnet" {
  name                = "azure-vpn-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.11.0.0/16"]
}

resource "azurerm_subnet" "azure_gateway_subnet" {
  name                 = "GatewaySubnet" # MUST be exactly named GatewaySubnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.azure_vnet.name
  address_prefixes     = ["10.11.0.0/24"]
}

resource "azurerm_subnet" "azure_vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.azure_vnet.name
  address_prefixes     = ["10.11.1.0/24"]
}

# 2. Azure Public IPs (2 required for Active-Active HA VPN)
resource "azurerm_public_ip" "azure_gw_pip1" {
  name                = "azure-gw-pip1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [domain_name_label]
  }
}

resource "azurerm_public_ip" "azure_gw_pip2" {
  name                = "azure-gw-pip2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [domain_name_label]
  }
}

# 3. Azure HA VPN Gateway
resource "azurerm_virtual_network_gateway" "azure_gateway" {
  name                = "azure-ha-vpn"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  active_active = true
  bgp_enabled   = true
  sku           = "VpnGw1AZ"

  bgp_settings {
    asn = 64513 # Azure's local ASN
    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig1"
      apipa_addresses       = ["169.254.21.2"]
    }
    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig2"
      apipa_addresses       = ["169.254.21.6"]
    }
  }

  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.azure_gw_pip1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.azure_gateway_subnet.id
  }

  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.azure_gw_pip2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.azure_gateway_subnet.id
  }
}

# 4. Azure Local Network Gateways (Represents the 2 STACKIT Tunnels)
resource "azurerm_local_network_gateway" "stackit_tunnel1" {
  name                = "stackit-tunnel-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = data.restful_resource.vpn_01_gateway_status.output.tunnels[0].publicIP

  bgp_settings {
    asn                 = 64512
    bgp_peering_address = "169.254.21.1"
  }
}

resource "azurerm_local_network_gateway" "stackit_tunnel2" {
  name                = "stackit-tunnel-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = data.restful_resource.vpn_01_gateway_status.output.tunnels[1].publicIP

  bgp_settings {
    asn                 = 64512
    bgp_peering_address = "169.254.21.5"
  }
}

# 5. Azure VPN Connections
resource "azurerm_virtual_network_gateway_connection" "azure_tunnel1" {
  name                = "conn-to-stackit-tunnel1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.azure_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.stackit_tunnel1.id
  shared_key                 = random_password.vpn_psk.result
  enable_bgp                 = true

  ipsec_policy {
    ike_encryption   = "GCMAES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    dh_group         = "DHGroup14"
    pfs_group        = "PFS14"
    sa_lifetime      = 3600
    sa_datasize      = 102400000
  }
}

resource "azurerm_virtual_network_gateway_connection" "azure_tunnel2" {
  name                = "conn-to-stackit-tunnel2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.azure_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.stackit_tunnel2.id
  shared_key                 = random_password.vpn_psk.result
  enable_bgp                 = true

  ipsec_policy {
    ike_encryption   = "GCMAES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    dh_group         = "DHGroup14"
    pfs_group        = "PFS14"
    sa_lifetime      = 3600
    sa_datasize      = 102400000
  }
}

# Connection from STACKIT to Azure
resource "restful_resource" "vpn_01_connection" {
  provider = restful.stackit
  path     = "${restful_resource.vpn_01_gateway.id}/connections"
  body = {
    displayName = "conn-to-azure"
    tunnel1 = {
      bgp = {
        remoteAsn = 64513
      }
      peering = {
        localAddress  = "169.254.21.1"
        remoteAddress = "169.254.21.2"
      }
      phase1 = {
        dhGroups             = ["modp2048"]
        encryptionAlgorithms = ["aes256gcm16"]
        integrityAlgorithms  = ["sha2_256"]
      }
      phase2 = {
        dhGroups             = ["modp2048"]
        encryptionAlgorithms = ["aes256gcm16"]
        integrityAlgorithms  = ["sha2_256"]
      }
      preSharedKey  = random_password.vpn_psk.result
      remoteAddress = azurerm_public_ip.azure_gw_pip1.ip_address
    }
    tunnel2 = {
      bgp = {
        remoteAsn = 64513
      }
      peering = {
        localAddress  = "169.254.21.5"
        remoteAddress = "169.254.21.6"
      }
      phase1 = {
        dhGroups             = ["modp2048"]
        encryptionAlgorithms = ["aes256gcm16"]
        integrityAlgorithms  = ["sha2_256"]
      }
      phase2 = {
        dhGroups             = ["modp2048"]
        encryptionAlgorithms = ["aes256gcm16"]
        integrityAlgorithms  = ["sha2_256"]
      }
      preSharedKey  = random_password.vpn_psk.result
      remoteAddress = azurerm_public_ip.azure_gw_pip2.ip_address
    }
  }

  lifecycle {
    ignore_changes = [
      body.tunnel1.preSharedKey,
      body.tunnel2.preSharedKey
    ]
  }

  read_path     = "$(path)/$(body.id)"
  update_path   = "$(path)/$(body.id)"
  update_method = "PUT"
  delete_path   = "$(path)/$(body.id)"
  delete_method = "DELETE"
}

# Azure Test VM & NSG
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "test-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-STACKIT"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.10.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "test-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azure_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_linux_virtual_machine" "azure_test_vm" {
  name                            = "azure-vpn-test-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  admin_password                  = "VpnTestPassw0rd!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Outputs
output "vpn01_public_ip" {
  value       = module.vpn_sna_01.machine_public_ip
  description = "Connect here via SSH to ping Azure"
}

output "vpn01_private_ip" {
  value = module.vpn_sna_01.machine_private_ipv4
}

output "azure_test_vm_private_ip" {
  value = azurerm_linux_virtual_machine.azure_test_vm.private_ip_address
}

# Command to run a ping test without SSHing
output "azure_run_command_ping_test" {
  value       = "az vm run-command invoke --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_linux_virtual_machine.azure_test_vm.name} --command-id RunShellScript --scripts 'ping -c 4 ${module.vpn_sna_01.machine_private_ipv4}'"
  description = "Copy and paste this in your terminal to securely ping from the Azure VM to the STACKIT VM."
}
