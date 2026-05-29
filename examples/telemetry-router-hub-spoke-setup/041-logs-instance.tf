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

resource "stackit_logs_instance" "this" {
  project_id     = stackit_resourcemanager_project.telemetry_hub.project_id
  region         = "eu01"
  display_name   = "telemetry_hub"
  retention_days = 30
  acl            = ["0.0.0.0/0"]
}

resource "stackit_logs_access_token" "router_ingest" {
  project_id   = stackit_resourcemanager_project.telemetry_hub.project_id
  instance_id  = stackit_logs_instance.this.instance_id
  display_name = "router-ingest-token"
  permissions  = ["write", "read"]
}
