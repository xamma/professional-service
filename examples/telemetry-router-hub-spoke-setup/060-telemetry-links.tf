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

# Link Hub Project to the Hub Router
# NOTE: The existence of a Telemetry Router in a project DOES NOT automatically link that project's logs.
# Every project (including the hub) must have an explicit Telemetry Link to forward its logs to a router.
resource "stackit_telemetrylink" "hub_link" {
  resource_type       = "project"
  resource_id         = stackit_resourcemanager_project.telemetry_hub.project_id
  display_name        = "hub-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}

# Link Spoke Project 1 to the Hub Router
resource "stackit_telemetrylink" "spoke1_link" {
  resource_type       = "project"
  resource_id         = stackit_resourcemanager_project.telemetry_spoke1.project_id
  display_name        = "spoke1-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}

# Link Spoke Project 2 to the Hub Router
resource "stackit_telemetrylink" "spoke2_link" {
  resource_type       = "project"
  resource_id         = stackit_resourcemanager_project.telemetry_spoke2.project_id
  display_name        = "spoke2-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}

# Link Spoke Project 3 to the Hub Router
resource "stackit_telemetrylink" "spoke3_link" {
  resource_type       = "project"
  resource_id         = stackit_resourcemanager_project.telemetry_spoke3.project_id
  display_name        = "spoke3-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}

# Link the entire Folder to the Hub Router
# This allows telemetry data from all projects within the folder (if configured) to be routed via the hub router
resource "stackit_telemetrylink" "folder_link" {
  resource_type       = "folder"
  resource_id         = stackit_resourcemanager_folder.this.folder_id
  display_name        = "folder-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}

# Link the entire Organization to the Hub Router
# This is used to forward organization-level audit logs to the central router
resource "stackit_telemetrylink" "org_link" {
  resource_type       = "organization"
  resource_id         = var.stackit_org_id
  display_name        = "org-to-hub-link"
  telemetry_router_id = stackit_telemetryrouter_instance.hub_router.instance_id
  access_token        = stackit_telemetryrouter_access_token.hub_router_token.access_token
}
