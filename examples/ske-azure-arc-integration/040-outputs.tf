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

output "kubeconfig" {
  value     = module.ske.kubeconfig
  sensitive = true
}

output "cluster_name" {
  value = module.ske.cluster_name
}

output "azure_resource_group" {
  value = azurerm_resource_group.arc_rg.name
}

output "azure_location" {
  value = azurerm_resource_group.arc_rg.location
}
