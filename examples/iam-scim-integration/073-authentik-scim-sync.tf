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

data "authentik_property_mapping_provider_scim" "scim_user" {
  managed_list = [
    "goauthentik.io/providers/scim/user"
  ]
}

data "authentik_property_mapping_provider_scim" "scim_group" {
  managed_list = [
    "goauthentik.io/providers/scim/group"
  ]
}

resource "authentik_provider_scim" "stackit" {
  name = "stackit-scim"
  url  = "https://accounts.stackit.cloud/scim/v2/"

  token = var.authentik_scim_long_lived_token

  property_mappings       = data.authentik_property_mapping_provider_scim.scim_user.ids
  property_mappings_group = data.authentik_property_mapping_provider_scim.scim_group.ids

  exclude_users_service_account = true
}

resource "authentik_application" "stackit" {
  name              = "STACKIT"
  slug              = "stackit"
  protocol_provider = authentik_provider_oauth2.stackit.id

  # Connects the SCIM provisioning pipeline to this application
  backchannel_providers = [
    authentik_provider_scim.stackit.id
  ]
}
