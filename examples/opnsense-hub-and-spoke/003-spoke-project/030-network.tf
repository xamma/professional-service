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

resource "stackit_routing_table" "rt_default" {
  name            = "rt_spoke_003"
  network_area_id = var.stackit_network_area_id
  organization_id = var.stackit_organization_id
  system_routes   = false
}

resource "stackit_routing_table_route" "default" {
  destination = {
    type  = "cidrv4"
    value = "0.0.0.0/0"
  }
  next_hop = {
    type  = "ipv4"
    value = var.hub_firewall_lan_ip
  }
  network_area_id  = var.stackit_network_area_id
  organization_id  = var.stackit_organization_id
  routing_table_id = stackit_routing_table.rt_default.routing_table_id
}

resource "stackit_network" "spoke_network" {
  project_id       = stackit_resourcemanager_project.spoke.project_id
  name             = "spoke-network"
  ipv4_nameservers = ["1.1.1.1", "9.9.9.9"]
  ipv4_prefix      = var.spoke_subnet
  routing_table_id = stackit_routing_table.rt_default.routing_table_id
}
