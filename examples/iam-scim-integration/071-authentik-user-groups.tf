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

resource "authentik_user" "test_users" {
  count = var.authentik_number_of_users

  username = "testuser${count.index + 1}"
  name     = "Test User ${count.index + 1}"
  email    = "testuser${count.index + 1}@${stackit_dns_zone.this.dns_name}"

  password = var.authentik_default_user_password

  attributes = jsonencode({
    given_name         = "Test${count.index + 1}"
    family_name        = "User ${count.index + 1}"
    preferred_username = "testuser${count.index + 1}"
  })

  depends_on = [time_sleep.wait_60_seconds]
}

resource "authentik_group" "stackit_test_user" {
  name       = "stackit-admins"
  users      = authentik_user.test_users[*].id
  depends_on = [time_sleep.wait_60_seconds]
}

data "authentik_property_mapping_provider_scope" "scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]

  depends_on = [time_sleep.wait_60_seconds]
}
