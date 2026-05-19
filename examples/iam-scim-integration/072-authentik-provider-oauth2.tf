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

resource "random_password" "authentik_client_secret" {
  length  = 40
  special = true
}

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"

  depends_on = [time_sleep.wait_60_seconds]
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"

  depends_on = [time_sleep.wait_60_seconds]
}

resource "authentik_property_mapping_provider_scope" "stackit_custom_claims" {
  name       = "stackit-custom-claims"
  scope_name = "profile" # Attaches this data to the standard 'profile' scope
  expression = <<EOT
return {
    "given_name": request.user.attributes.get("given_name", request.user.name),
    "family_name": request.user.attributes.get("family_name", request.user.name),
    "preferred_username": request.user.attributes.get("preferred_username", request.user.username)
}
EOT
}

data "authentik_certificate_key_pair" "this" {
  name = "authentik Self-signed Certificate"
}

resource "authentik_provider_oauth2" "stackit" {
  name          = "stackit"
  client_id     = "stackit-client"
  client_secret = random_password.authentik_client_secret.result

  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://accounts.stackit.cloud/ui/login/login/externalidp/callback"
    },
    # debugging
    {
      matching_mode = "strict"
      url           = "http://localhost:8080/ui/login/login/externalidp/callback"
    }
  ]

  signing_key = data.authentik_certificate_key_pair.this.id

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.stackit_custom_claims.id]
  )

  include_claims_in_id_token = true

  depends_on = [time_sleep.wait_60_seconds]

  lifecycle {
    prevent_destroy = true
  }
}
