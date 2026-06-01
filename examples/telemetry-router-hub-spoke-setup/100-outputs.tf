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

output "telemetry_router_id" {
  description = "The ID of the central Telemetry Router"
  value       = stackit_telemetryrouter_instance.hub_router.instance_id
}

output "telemetry_router_uri" {
  description = "The OTLP ingest URI of the central Telemetry Router"
  value       = stackit_telemetryrouter_instance.hub_router.uri
}

output "spoke1_link_id" {
  description = "The ID of the Telemetry Link for Spoke Project 1"
  value       = stackit_telemetrylink.spoke1_link.id
}

output "spoke2_link_id" {
  description = "The ID of the Telemetry Link for Spoke Project 2"
  value       = stackit_telemetrylink.spoke2_link.id
}

output "spoke3_link_id" {
  description = "The ID of the Telemetry Link for Spoke Project 3"
  value       = stackit_telemetrylink.spoke3_link.id
}

output "folder_link_id" {
  description = "The ID of the Telemetry Link for the parent Folder"
  value       = stackit_telemetrylink.folder_link.id
}

output "org_link_id" {
  description = "The ID of the Telemetry Link for the Organization"
  value       = stackit_telemetrylink.org_link.id
}

output "observability_logs_ingest_url" {
  description = "The OTLP HTTP logs ingest URL for the Observability instance"
  value       = stackit_observability_instance.this.otlp_http_logs_url
}

output "logs_ingest_url" {
  description = "The OTLP ingest URL for the Logs instance"
  value       = "https://${stackit_logs_instance.this.ingest_otlp_url}"
}

output "s3_archive_bucket" {
  description = "The name of the S3 bucket used for log archiving"
  value       = stackit_objectstorage_bucket.log_archive.name
}

output "s3_access_key" {
  description = "The S3 access key for the log archive bucket"
  value       = stackit_objectstorage_credential.router_s3_creds.access_key
}

output "s3_secret_key" {
  description = "The S3 secret access key for the log archive bucket"
  value       = stackit_objectstorage_credential.router_s3_creds.secret_access_key
  sensitive   = true
}

output "s3_endpoint" {
  description = "The S3 endpoint for the log archive bucket"
  value       = regex("^https://[^/]+", stackit_objectstorage_bucket.log_archive.url_path_style)
}
