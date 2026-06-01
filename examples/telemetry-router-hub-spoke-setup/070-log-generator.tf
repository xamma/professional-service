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

# This file creates resources that are rotated every minute.
# The frequent rotation of credentials triggers audit logs in each project,
# allowing us to verify that the Telemetry Router and Links are working as expected.

resource "time_rotating" "minute" {
  rotation_minutes = 1
}

locals {
  projects = {
    hub    = stackit_resourcemanager_project.telemetry_hub.project_id
    spoke1 = stackit_resourcemanager_project.telemetry_spoke1.project_id
    spoke2 = stackit_resourcemanager_project.telemetry_spoke2.project_id
    spoke3 = stackit_resourcemanager_project.telemetry_spoke3.project_id
  }
}

# Create a bucket in each project
resource "stackit_objectstorage_bucket" "log_gen" {
  for_each   = local.projects
  project_id = each.value
  name       = "log-gen-bucket-${each.key}"
}

# Create a credentials group in each project
resource "stackit_objectstorage_credentials_group" "log_gen" {
  for_each   = local.projects
  project_id = each.value
  name       = "log-gen-group-${each.key}"

  depends_on = [stackit_objectstorage_bucket.log_gen]
}

# Create a credential in each project and rotate it every minute
resource "stackit_objectstorage_credential" "log_gen" {
  for_each             = local.projects
  project_id           = each.value
  credentials_group_id = stackit_objectstorage_credentials_group.log_gen[each.key].credentials_group_id

  # This map forces recreation of the credential whenever the time_rotating resource rotates
  rotate_when_changed = {
    rotation_id = time_rotating.minute.id
  }
}

# Create a service account in each project to generate more IAM-related audit logs
resource "stackit_service_account" "log_gen" {
  for_each   = local.projects
  project_id = each.value
  name       = "log-gen-sa-${each.key}"
}


resource "stackit_service_account_key" "log_gen" {
  for_each              = local.projects
  project_id            = each.value
  service_account_email = stackit_service_account.log_gen[each.key].email

  rotate_when_changed = {
    rotation = time_rotating.minute.id
  }
}

# Assign the 'reader' role to each service account (using IAM experimental resources)
resource "stackit_authorization_project_role_assignment" "log_gen" {
  for_each    = local.projects
  resource_id = each.value
  role        = "reader"
  subject     = stackit_service_account.log_gen[each.key].email
}
