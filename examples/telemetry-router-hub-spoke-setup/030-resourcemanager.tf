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

resource "stackit_resourcemanager_folder" "this" {
  name                = "telemetry-router-link-test"
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org_id
}

resource "stackit_resourcemanager_project" "telemetry_hub" {
  parent_container_id = stackit_resourcemanager_folder.this.container_id
  name                = "telemetry_hub"
  owner_email         = var.stackit_owner_email
}

resource "stackit_resourcemanager_project" "telemetry_spoke1" {
  parent_container_id = stackit_resourcemanager_folder.this.container_id
  name                = "telemetry_spoke1"
  owner_email         = var.stackit_owner_email
}

resource "stackit_resourcemanager_project" "telemetry_spoke2" {
  parent_container_id = stackit_resourcemanager_folder.this.container_id
  name                = "telemetry_spoke2"
  owner_email         = var.stackit_owner_email
}

resource "stackit_resourcemanager_project" "telemetry_spoke3" {
  parent_container_id = stackit_resourcemanager_folder.this.container_id
  name                = "telemetry_spoke3"
  owner_email         = var.stackit_owner_email
}
