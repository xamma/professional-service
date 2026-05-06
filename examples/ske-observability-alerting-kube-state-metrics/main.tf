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

resource "stackit_ske_cluster" "example" {
  project_id             = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  name                   = "example"
  kubernetes_version_min = "1.31"
  node_pools = [
    {
      name               = "standard"
      machine_type       = "c2i.4"
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

resource "kubernetes_secret" "argus_prometheus_authorization" {
  metadata {
    name      = "argus-prometheus-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    username = stackit_observability_credential.example.username
    password = stackit_observability_credential.example.password
  }
}

resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "60.1.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    templatefile("prom-values.tftpl", {
      metrics_push_url = stackit_observability_instance.example.metrics_push_url
      secret_name      = kubernetes_secret.argus_prometheus_authorization.metadata[0].name
    })
  ]
}

resource "stackit_observability_alertgroup" "example" {
  project_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  instance_id = stackit_observability_instance.example.instance_id
  name        = "TestAlertGroup"
  interval    = "2h"
  rules = [
    {
      alert      = "SimplePodCheck"
      expression = "sum(kube_pod_status_phase{phase=\"Running\", namespace=\"example\"}) > 0"
      for        = "60s"
      labels = {
        severity = "critical"
      },
      annotations = {
        summary     = "Test Alert is working"
        description = "Test Alert"
      }
    },
  ]
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "example"
  }
}

resource "kubernetes_pod" "example" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    container {
      image = "nginx:latest"
      name  = "nginx"
    }
  }
}
