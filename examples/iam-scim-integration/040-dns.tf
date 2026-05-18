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

resource "stackit_public_ip" "ingress_floating_ip" {
  project_id = var.stackit_project_id

  lifecycle {
    ignore_changes = [network_interface_id]
  }
}

resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}

resource "stackit_dns_zone" "this" {
  project_id    = var.stackit_project_id
  name          = random_string.this.result
  dns_name      = "${random_string.this.result}.runs.onstackit.cloud"
  type          = "primary"
  default_ttl   = 60
  contact_email = "hostmaster@stackit.cloud"
}

resource "stackit_dns_record_set" "authentik" {
  project_id = var.stackit_project_id
  zone_id    = stackit_dns_zone.this.zone_id
  name       = "authentik"
  type       = "A"
  ttl        = 60
  comment    = "a record"
  records    = [stackit_public_ip.ingress_floating_ip.ip]
}
