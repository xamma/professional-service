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

# Enable Project-level Compliance Lock (required for WORM / Object Lock)
resource "stackit_objectstorage_compliance_lock" "hub_lock" {
  project_id = stackit_resourcemanager_project.telemetry_hub.project_id
}

# Create an S3 Bucket with Object Lock enabled for immutable log archiving (WORM)
resource "stackit_objectstorage_bucket" "log_archive" {
  project_id  = stackit_resourcemanager_project.telemetry_hub.project_id
  name        = "telemetry-immutable-archive"
  object_lock = true

  # Ensure the compliance lock is active before creating the bucket with object lock
  depends_on = [stackit_objectstorage_compliance_lock.hub_lock]
}

# Create a Credentials Group for Object Storage
resource "stackit_objectstorage_credentials_group" "router_group" {
  project_id = stackit_resourcemanager_project.telemetry_hub.project_id
  name       = "router-s3-group"
}

# Create Credentials for the Telemetry Router to access the bucket
resource "stackit_objectstorage_credential" "router_s3_creds" {
  project_id           = stackit_resourcemanager_project.telemetry_hub.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.router_group.credentials_group_id
}
