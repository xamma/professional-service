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

# GCP VPC and Subnet
resource "google_compute_network" "gcp_vpc" {
  name                    = "gcp-vpn-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gcp_subnet" {
  name          = "gcp-vpn-subnet"
  ip_cidr_range = "10.11.0.0/16"
  region        = "europe-west4"
  network       = google_compute_network.gcp_vpc.id
}

# GCP HA VPN Gateway
resource "google_compute_ha_vpn_gateway" "gcp_gateway" {
  name    = "gcp-ha-vpn"
  network = google_compute_network.gcp_vpc.id
  region  = "europe-west4"
}

# GCP Cloud Router (for BGP)
resource "google_compute_router" "gcp_router" {
  name    = "gcp-router"
  network = google_compute_network.gcp_vpc.name
  region  = "europe-west4"
  bgp {
    asn = 64513 # GCP's local ASN
  }
}

# GCP External VPN Gateway (Represents STACKIT in GCP)
resource "google_compute_external_vpn_gateway" "stackit_gateway" {
  name            = "stackit-external-gw"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  description     = "STACKIT VPN Gateway"

  # Fetching the public IPs from STACKIT
  interface {
    id         = 0
    ip_address = data.restful_resource.vpn_01_gateway_status.output.tunnels[0].publicIP
  }
  interface {
    id         = 1
    ip_address = data.restful_resource.vpn_01_gateway_status.output.tunnels[1].publicIP
  }
}

# GCP VPN Tunnels
resource "google_compute_vpn_tunnel" "gcp_tunnel1" {
  name                            = "gcp-tunnel-1"
  region                          = "europe-west4"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.stackit_gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = random_password.vpn_psk.result
  router                          = google_compute_router.gcp_router.id
  vpn_gateway_interface           = 0
}

resource "google_compute_vpn_tunnel" "gcp_tunnel2" {
  name                            = "gcp-tunnel-2"
  region                          = "europe-west4"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.stackit_gateway.id
  peer_external_gateway_interface = 1
  shared_secret                   = random_password.vpn_psk.result
  router                          = google_compute_router.gcp_router.id
  vpn_gateway_interface           = 1
}

# GCP Cloud Router Interfaces & BGP Peers
resource "google_compute_router_interface" "gcp_router_interface1" {
  name       = "gcp-interface-1"
  router     = google_compute_router.gcp_router.name
  region     = "europe-west4"
  ip_range   = "169.254.0.2/30" # GCP's local BGP IP
  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel1.name
}

resource "google_compute_router_peer" "gcp_router_peer1" {
  name                      = "gcp-peer-1"
  router                    = google_compute_router.gcp_router.name
  region                    = "europe-west4"
  peer_ip_address           = "169.254.0.1" # STACKIT's local BGP IP
  peer_asn                  = 64512         # STACKIT's ASN
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp_router_interface1.name
}

resource "google_compute_router_interface" "gcp_router_interface2" {
  name       = "gcp-interface-2"
  router     = google_compute_router.gcp_router.name
  region     = "europe-west4"
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel2.name
}

resource "google_compute_router_peer" "gcp_router_peer2" {
  name                      = "gcp-peer-2"
  router                    = google_compute_router.gcp_router.name
  region                    = "europe-west4"
  peer_ip_address           = "169.254.1.1"
  peer_asn                  = 64512
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp_router_interface2.name
}

# Connection from STACKIT to GCP
resource "restful_resource" "vpn_01_connection" {
  provider = restful.stackit
  path     = "${restful_resource.vpn_01_gateway.id}/connections"
  body = {
    displayName = "conn-to-gcp"
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
      remoteAddress = google_compute_ha_vpn_gateway.gcp_gateway.vpn_interfaces[0].ip_address
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
      remoteAddress = google_compute_ha_vpn_gateway.gcp_gateway.vpn_interfaces[1].ip_address
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

# GCP Test VM & Firewall Rules
# Firewall: Allow Identity-Aware Proxy (IAP) to SSH into the VM
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.gcp_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["test-vm"]
}

# Firewall: Allow STACKIT to ping/SSH into the GCP VM over the VPN
resource "google_compute_firewall" "allow_stackit_vpn_traffic" {
  name    = "allow-stackit-vpn-traffic"
  network = google_compute_network.gcp_vpc.name

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Your STACKIT SNA range
  source_ranges = ["10.10.0.0/16"]
  target_tags   = ["test-vm"]
}

# GCP Virtual Machine
resource "google_compute_instance" "gcp_test_vm" {
  name         = "gcp-vpn-test-vm"
  machine_type = "e2-micro"
  zone         = "europe-west4-a"

  tags = ["test-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gcp_subnet.id
    # Omitting the 'access_config' block ensures this VM gets NO public IP address.
  }
}

# Outputs
output "vpn01_public_ip" {
  value = module.vpn_sna_01.machine_public_ip
}

output "vpn01_private_ip" {
  value = module.vpn_sna_01.machine_private_ipv4
}

output "gcp_test_vm_private_ip" {
  value = google_compute_instance.gcp_test_vm.network_interface[0].network_ip
}

output "gcp_iap_command" {
  value = "gcloud compute ssh ${google_compute_instance.gcp_test_vm.name} --tunnel-through-iap"
}
