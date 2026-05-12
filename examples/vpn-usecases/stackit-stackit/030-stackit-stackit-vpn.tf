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

module "vpn_sna_01" {
  source                    = "../module/stackit-sna-with-debug-machine"
  machine_availability_zone = "eu01-1"
  machine_ipv4_prefix       = "10.10.10.0/24"
  machine_network_name      = "vpn-sna-01"
  sna_name                  = "vpn-sna-01"
  machine_name              = "vpn-sna-01"
  stackit_admin_email       = "mauritz.uphoff@digits.schwarz"
  stackit_org_id            = var.stackit_org_id
  stackit_project_name      = "vpn-sna-01"
  sna_network_range_prefix = [
    "10.10.0.0/16"
  ]
}

module "vpn_sna_02" {
  source                    = "../module/stackit-sna-with-debug-machine"
  machine_availability_zone = "eu01-2"
  machine_ipv4_prefix       = "10.11.11.0/24"
  machine_network_name      = "vpn-sna-02"
  machine_name              = "vpn-sna-02"
  sna_name                  = "vpn-sna-02"
  stackit_admin_email       = "mauritz.uphoff@digits.schwarz"
  stackit_org_id            = var.stackit_org_id
  stackit_project_name      = "vpn-sna-02"
  sna_network_range_prefix = [
    "10.11.0.0/16"
  ]
}

# Gateway 1 (vpn-sna-01)
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

# Gateway 2 (vpn-sna-02)
resource "restful_resource" "vpn_02_gateway" {
  provider = restful.stackit
  path     = "/v1/projects/${module.vpn_sna_02.project_id}/regions/eu01/gateways"
  body = {
    availabilityZones = {
      tunnel1 = "eu01-1"
      tunnel2 = "eu01-2"
    }
    bgp = {
      localAsn                 = 64513
      overrideAdvertisedRoutes = ["10.11.0.0/16"]
    }
    displayName = "vpn02"
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

data "restful_resource" "vpn_02_gateway_status" {
  provider = restful.stackit
  id       = "${restful_resource.vpn_02_gateway.id}/status"
}

# Shared VPN Credentials
resource "random_password" "vpn_psk" {
  length  = 32
  special = false
}

# Connection from Gateway 1 to Gateway 2
resource "restful_resource" "vpn_01_connection" {
  provider = restful.stackit
  path     = "${restful_resource.vpn_01_gateway.id}/connections"
  body = {
    displayName = "conn-to-vpn02"
    tunnel1 = {
      bgp = {
        remoteAsn = 64513
      }
      peering = {
        localAddress  = "169.254.0.1"
        remoteAddress = "169.254.0.2"
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
      remoteAddress = data.restful_resource.vpn_02_gateway_status.output.tunnels[0].publicIP
    }
    tunnel2 = {
      bgp = {
        remoteAsn = 64513
      }
      peering = {
        localAddress  = "169.254.1.1"
        remoteAddress = "169.254.1.2"
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
      remoteAddress = data.restful_resource.vpn_02_gateway_status.output.tunnels[1].publicIP
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

# Connection from Gateway 2 to Gateway 1
resource "restful_resource" "vpn_02_connection" {
  provider = restful.stackit
  path     = "${restful_resource.vpn_02_gateway.id}/connections"
  body = {
    displayName = "conn-to-vpn01"
    tunnel1 = {
      bgp = {
        remoteAsn = 64512
      }
      peering = {
        localAddress  = "169.254.0.2"
        remoteAddress = "169.254.0.1"
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
      remoteAddress = data.restful_resource.vpn_01_gateway_status.output.tunnels[0].publicIP
    }
    tunnel2 = {
      bgp = {
        remoteAsn = 64512
      }
      peering = {
        localAddress  = "169.254.1.2"
        remoteAddress = "169.254.1.1"
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
      remoteAddress = data.restful_resource.vpn_01_gateway_status.output.tunnels[1].publicIP
    }
  }

  read_path     = "$(path)/$(body.id)"
  update_path   = "$(path)/$(body.id)"
  update_method = "PUT"
  delete_path   = "$(path)/$(body.id)"
  delete_method = "DELETE"

  lifecycle {
    ignore_changes = [
      body.tunnel1.preSharedKey,
      body.tunnel2.preSharedKey
    ]
  }
}

output "vpn01_public_ip" {
  value = module.vpn_sna_01.machine_public_ip
}

output "vpn01_private_ip" {
  value = module.vpn_sna_01.machine_private_ipv4
}

output "vpn02_public_ip" {
  value = module.vpn_sna_02.machine_public_ip
}

output "vpn02_private_ip" {
  value = module.vpn_sna_02.machine_private_ipv4
}
