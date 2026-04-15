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

resource "stackit_ske_cluster" "default" {
  project_id             = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  name                   = "ske-enc-vol"
  kubernetes_version_min = "1.33"

  node_pools = [{
    name               = "standard"
    machine_type       = "c2i.4"
    minimum            = 1
    maximum            = 3
    availability_zones = ["eu01-1"]
    os_name            = "flatcar"
    volume_size        = 32
  }]
}

resource "stackit_ske_kubeconfig" "default" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  cluster_name = stackit_ske_cluster.default.name
  refresh      = true
}

# ------------------------------------------------------------------------
# 2. Identify the Internal SKE Service Account
# ------------------------------------------------------------------------
data "stackit_service_accounts" "ske_internal" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  email_suffix = "@ske.sa.stackit.cloud"

  depends_on = [stackit_ske_cluster.default]
}

# ------------------------------------------------------------------------
# 3. Setup KMS Infrastructure
# ------------------------------------------------------------------------
resource "stackit_kms_keyring" "encryption" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  display_name = "ske-volume-keyring"
}

resource "stackit_kms_key" "volume_key" {
  project_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  keyring_id   = stackit_kms_keyring.encryption.keyring_id
  display_name = "volume-encryption-key"
  protection   = "software"
  algorithm    = "aes_256_gcm"
  purpose      = "symmetric_encrypt_decrypt"
}

# ------------------------------------------------------------------------
# 4. Configure Identity and Permissions (Act-As)
# ------------------------------------------------------------------------
# Create the service account that 'owns' the KMS access
resource "stackit_service_account" "kms_manager" {
  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  name       = "volume-encryptor"
}

# Grant the 'kms.admin' role to the manager service-account
resource "stackit_authorization_project_role_assignment" "kms_user" {
  // in this case the STACKIT project_id
  resource_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  role        = "kms.admin"
  subject     = stackit_service_account.kms_manager.email
}

# Authorize the internal SKE account to impersonate the kms manager service-account (Act-As)
resource "stackit_authorization_service_account_role_assignment" "ske_impersonation" {
  resource_id = stackit_service_account.kms_manager.service_account_id
  role        = "user"
  subject     = data.stackit_service_accounts.ske_internal.items[0].email
}

resource "kubernetes_storage_class_v1" "encrypted_premium" {
  metadata {
    name = "stackit-encrypted-premium"
  }

  storage_provisioner    = "block-storage.csi.stackit.cloud"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type              = "storage_premium_perf6"
    encrypted         = "true"
    kmsKeyID          = stackit_kms_key.volume_key.key_id
    kmsKeyringID      = stackit_kms_keyring.encryption.keyring_id
    kmsProjectID      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    kmsKeyVersion     = "1"
    kmsServiceAccount = stackit_service_account.kms_manager.email
  }

  depends_on = [
    stackit_authorization_service_account_role_assignment.ske_impersonation,
    stackit_authorization_project_role_assignment.kms_user
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "test_pvc" {
  metadata {
    name = "test-encryption-pvc"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }

    storage_class_name = kubernetes_storage_class_v1.encrypted_premium.metadata[0].name
  }
}

# ------------------------------------------------------------------------
# 7. Create a Pod to Consume the Volume
# ------------------------------------------------------------------------
resource "kubernetes_pod_v1" "test_app" {
  metadata {
    name = "encrypted-volume-test"
  }

  spec {
    container {
      image = "nginx:latest"
      name  = "web-server"

      volume_mount {
        mount_path = "/usr/share/nginx/html"
        name       = "data-volume"
      }
    }

    volume {
      name = "data-volume"
      persistent_volume_claim {
        claim_name = "test-encryption-pvc"
      }
    }
  }
}
