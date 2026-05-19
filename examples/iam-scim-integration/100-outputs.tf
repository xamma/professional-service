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

output "authentik_url" {
  value = "https://${stackit_dns_record_set.authentik.name}.${stackit_dns_zone.this.dns_name}"
}

output "authentik_oidc_issuer" {
  description = "Issuer identifier URL for your OIDC provider"
  value       = "https://${stackit_dns_record_set.authentik.name}.${stackit_dns_zone.this.dns_name}/application/o/stackit/"
}

output "authentik_oidc_client_id" {
  description = "ID assigned to our application"
  value       = authentik_provider_oauth2.stackit.client_id
}

output "authentik_oidc_client_secret" {
  description = "Secret key associated with the Client ID"
  value       = random_password.authentik_client_secret.result
  sensitive   = true
}

output "stackit_ticket_scopes" {
  description = "Required permissions to include in the STACKIT Support Ticket"
  value       = "openid email profile"
}

output "stackit_ticket_claims_mapping" {
  description = "Standard Authentik claims mapping to copy into the STACKIT Support Ticket"
  value = {
    unique_user_id = "sub"
    email_address  = "email"
    preferred_name = "preferred_username" # Or "name"
    first_name     = "given_name"
    last_name      = "family_name"
  }
}
