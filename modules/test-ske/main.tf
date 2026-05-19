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

data "stackit_ske_kubernetes_versions" "this" {
  version_state = "SUPPORTED"
}

data "stackit_ske_machine_image_versions" "this" {
  version_state = "SUPPORTED"
}

resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}

locals {
  flatcar_supported_versions = flatten([
    for mi in data.stackit_ske_machine_image_versions.this.machine_images : [
      for v in mi.versions : v.version if mi.name == "flatcar"
    ]
  ])
  flatcar_supported_version = length(local.flatcar_supported_versions) > 0 ? local.flatcar_supported_versions[0] : null

  ubuntu_supported_versions = flatten([
    for mi in data.stackit_ske_machine_image_versions.this.machine_images : [
      for v in mi.versions : v.version if mi.name == "ubuntu"
    ]
  ])
  ubuntu_supported_version = length(local.ubuntu_supported_versions) > 0 ? local.ubuntu_supported_versions[0] : null
}

resource "stackit_ske_cluster" "this" {
  project_id             = var.project_id
  name                   = var.cluster_name != null && var.cluster_name != "" ? var.cluster_name : "ske-${random_string.this.result}"
  kubernetes_version_min = data.stackit_ske_kubernetes_versions.this.kubernetes_versions[0].version

  maintenance = var.maintenance

  network = var.network_id != null && var.network_id != "" ? {
    id = var.network_id
  } : null

  node_pools = [
    for np in var.node_pools : {
      name               = np.name
      machine_type       = np.machine_type
      minimum            = np.minimum
      maximum            = np.maximum
      max_surge          = np.max_surge
      availability_zones = np.availability_zones
      os_name            = np.os_name
      # Dynamically injects the latest OS version based on os_name if not explicitly set
      os_version_min = lookup(np, "os_version_min", np.os_name == "flatcar" ? local.flatcar_supported_version : local.ubuntu_supported_version)
      volume_size    = np.volume_size
      volume_type    = np.volume_type
    }
  ]

  lifecycle {
    ignore_changes = [
      kubernetes_version_min,
      node_pools
    ]
  }
}

resource "stackit_ske_kubeconfig" "this" {
  project_id   = var.project_id
  cluster_name = stackit_ske_cluster.this.name
  refresh      = true
}
