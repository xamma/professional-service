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

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.2.3"

  namespace = kubernetes_namespace_v1.nginx.metadata.0.name

  values = [
    <<EOF
controller:
  replicaCount: 1
  service:
    type: LoadBalancer
    annotations:
      lb.stackit.cloud/ip-mode-proxy: "true"
      lb.stackit.cloud/external-address: ${stackit_public_ip.ingress_floating_ip.ip}
EOF
  ]

  timeout = 600
}
