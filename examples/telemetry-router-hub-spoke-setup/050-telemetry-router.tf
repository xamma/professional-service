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

# Create the Telemetry Router Instance in the Hub project
resource "stackit_telemetryrouter_instance" "hub_router" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  display_name = "hub-telemetry-router"
  description  = "Central Telemetry Router for spoke projects and parent folder"
}

# Create an Access Token for the Router
# This token will be used by the links to authenticate with the router
resource "stackit_telemetryrouter_access_token" "hub_router_token" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  instance_id  = stackit_telemetryrouter_instance.hub_router.instance_id
  display_name = "hub-router-link-token"
}

# Create a Destination for the Router to send all telemetry data to the central Observability instance
resource "stackit_telemetryrouter_destination" "observability_destination" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  instance_id  = stackit_telemetryrouter_instance.hub_router.instance_id
  display_name = "observability-dest"
  config = {
    config_type = "OpenTelemetry"
    opentelemetry = {
      # Obs-stack has https:// in the attribute
      uri = stackit_observability_instance.this.otlp_http_logs_url
      basic_auth = {
        username = stackit_observability_credential.router_ingest.username
        password = stackit_observability_credential.router_ingest.password
      }
    }
  }
}

# Create a Destination for the Router to send filtered logs to the central Logs instance
# We only want logs from the 'service-account' service
resource "stackit_telemetryrouter_destination" "logs_destination" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  instance_id  = stackit_telemetryrouter_instance.hub_router.instance_id
  display_name = "logs-dest"
  config = {
    config_type = "OpenTelemetry"
    filter = {
      attributes = [{
        key     = "service.name"
        level   = "logRecord"
        matcher = "="
        values  = ["service-account"]
      }]
    }
    opentelemetry = {
      # Prepend https:// as the OTLP URI must have a protocol
      uri          = "https://${stackit_logs_instance.this.ingest_otlp_url}"
      bearer_token = stackit_logs_access_token.router_ingest.access_token
    }
  }
}

# Create a Destination for the Router to archive all data in S3
resource "stackit_telemetryrouter_destination" "s3_archive" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  instance_id  = stackit_telemetryrouter_instance.hub_router.instance_id
  display_name = "s3-log-archive"
  config = {
    config_type = "S3"
    s3 = {
      access_key = {
        id     = stackit_objectstorage_credential.router_s3_creds.access_key
        secret = stackit_objectstorage_credential.router_s3_creds.secret_access_key
      }
      bucket   = stackit_objectstorage_bucket.log_archive.name
      endpoint = regex("^https://[^/]+", stackit_objectstorage_bucket.log_archive.url_path_style)
    }
  }
}
