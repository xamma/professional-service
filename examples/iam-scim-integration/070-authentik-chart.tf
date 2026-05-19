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

resource "random_password" "authentik_secret_key" {
  length  = 50
  special = true
}

resource "random_password" "authentik_bootstrap_password" {
  length  = 24
  special = true
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 40
  special = false
}

resource "random_password" "postgresql_password" {
  length  = 24
  special = false
}

locals {
  authentik_values = {
    authentik = {
      secret_key         = random_password.authentik_secret_key.result
      bootstrap_password = random_password.authentik_bootstrap_password.result
      bootstrap_token    = random_password.authentik_bootstrap_token.result
      postgresql = {
        user     = "authentik"
        name     = "authentik"
        password = random_password.postgresql_password.result
      }
    }
    postgresql = {
      enabled = true
      auth = {
        username = "authentik"
        database = "authentik"
        password = random_password.postgresql_password.result
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod-cluster"
        }
        hosts = [
          "${stackit_dns_record_set.authentik.name}.${stackit_dns_zone.this.dns_name}"
        ]
        paths = ["/"]
        tls = [
          {
            secretName = "authentik-tls"
            hosts = [
              "${stackit_dns_record_set.authentik.name}.${stackit_dns_zone.this.dns_name}"
            ]
          }
        ]
      }
    }
  }
}

resource "helm_release" "authentik" {
  name       = "authentik"
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = "2026.2.3"

  namespace = kubernetes_namespace_v1.authentik.metadata.0.name

  values = [
    yamlencode(local.authentik_values)
  ]

  timeout = 600
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [helm_release.authentik]

  create_duration = "60s"
}
