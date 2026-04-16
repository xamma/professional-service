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

output "network_area_id" {
  description = "Shared Network Area ID — required by all spoke projects."
  value       = local.sna_id
}

output "hub_project_id" {
  description = "STACKIT project ID of the hub."
  value       = local.hub_project_id
}

output "firewall_lan_ip" {
  description = "pfSense LAN IP — set as hub_firewall_lan_ip in spoke terraform.tfvars."
  value       = stackit_network_interface.nic_lan.ipv4
}

output "wan_public_ip" {
  description = "WAN public IP of the pfSense firewall."
  value       = stackit_public_ip.wan_public_ip.ip
}

output "mgmt_public_ip" {
  description = "Public IP of the pfSense MGMT interface. Access the web UI at https://<ip>/"
  value       = stackit_public_ip.mgmt_public_ip.ip
}
