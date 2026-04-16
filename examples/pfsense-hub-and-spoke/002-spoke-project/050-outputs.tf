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

output "spoke_project_id" {
  description = "STACKIT project ID of this spoke."
  value       = stackit_resourcemanager_project.spoke.project_id
}

output "server_a_ip" {
  description = "Primary IP address of server-a."
  value       = module.server_a.primary_ip
}

output "server_b_ip" {
  description = "Primary IP address of server-b."
  value       = module.server_b.primary_ip
}
