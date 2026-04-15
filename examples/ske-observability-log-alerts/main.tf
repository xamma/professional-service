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

provider "stackit" {
  default_region           = "eu01"
  service_account_key_path = ""
}

provider "kubernetes" {
  host                   = yamldecode(stackit_ske_kubeconfig.example.kube_config).clusters.0.cluster.server
  client_certificate     = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).users.0.user.client-certificate-data)
  client_key             = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).users.0.user.client-key-data)
  cluster_ca_certificate = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).clusters.0.cluster.certificate-authority-data)
}

provider "helm" {
  kubernetes {
    host                   = yamldecode(stackit_ske_kubeconfig.example.kube_config).clusters.0.cluster.server
    client_certificate     = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).users.0.user.client-certificate-data)
    client_key             = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).users.0.user.client-key-data)
    cluster_ca_certificate = base64decode(yamldecode(stackit_ske_kubeconfig.example.kube_config).clusters.0.cluster.certificate-authority-data)
  }
}

resource "stackit_ske_cluster" "example" {
  project_id             = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  name                   = "example"
  kubernetes_version_min = "1.31"
  node_pools = [
    {
      name               = "standard"
      machine_type       = "c1.4"
      minimum            = "3"
      maximum            = "9"
      max_surge          = "3"
      availability_zones = ["eu01-1", "eu01-2", "eu01-3"]
      os_version_min     = "4081.2.1"
      os_name            = "flatcar"
      volume_size        = 32
      volume_type        = "storage_premium_perf6"
    }
  ]
  maintenance = {
    enable_kubernetes_version_updates    = true
    enable_machine_image_version_updates = true
    start                                = "01:00:00Z"
    end                                  = "02:00:00Z"
  }
}

resource "stackit_ske_kubeconfig" "example" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  cluster_name = stackit_ske_cluster.example.name
  refresh      = true
}

locals {
  alert_config = {
    route = {
      receiver        = "EmailStackit",
      repeat_interval = "1m",
      continue        = true
    }
    receivers = [
      {
        name = "EmailStackit",
        email_configs = [
          {
            to = "<email>" # Replace with your actual email
          }
        ]
      }
    ]
  }
}

resource "stackit_observability_instance" "example" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  name         = "example"
  plan_name    = "Observability-Large-EU01"
  alert_config = local.alert_config
}

resource "stackit_observability_credential" "example" {
  project_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  instance_id = stackit_observability_instance.example.instance_id
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata.0.name
  version    = "6.16.4"

  values = [
    <<-EOF
    config:
      clients:
      # To find the Loki push URL, navigate to the observability instance in the portal and select the API tab.
      - url: "https://${stackit_observability_credential.example.username}:${stackit_observability_credential.example.password}@<your-loki-push-url>/instances/${stackit_observability_instance.example.instance_id}/loki/api/v1/push"
    EOF
  ]
}

resource "stackit_observability_logalertgroup" "example" {
  project_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  instance_id = stackit_observability_instance.example.instance_id
  name        = "TestLogAlertGroup"
  interval    = "1m"
  rules = [
    {
      alert      = "SimplePodLogAlertCheck"
      expression = "sum(rate({namespace=\"example\", pod=\"logger\"} |= \"Simulated error message\" [1m])) > 0"
      for        = "60s"
      labels = {
        severity = "critical"
      },
      annotations = {
        summary : "Test Log Alert is working"
        description : "Test Log Alert"
      },
    },
  ]
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "example"
  }
}

resource "kubernetes_pod" "logger" {
  metadata {
    name      = "logger"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels = {
      app = "logger"
    }
  }

  spec {
    container {
      name  = "logger"
      image = "bash"
      command = [
        "bash",
        "-c",
        <<EOF
        while true; do
          sleep $(shuf -i 1-3 -n 1)
          echo "ERROR: $(date) - Simulated error message $(shuf -i 1-100 -n 1)" 1>&2
        done
        EOF
      ]
    }
  }
}
