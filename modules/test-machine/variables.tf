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

variable "project_id" {
  description = "The STACKIT Project ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.project_id))
    error_message = "The project_id must be a valid UUID."
  }
}

variable "network_id" {
  description = "The Network ID (UUID) where the machine should be spawned"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.network_id))
    error_message = "The network_id must be a valid UUID."
  }
}

variable "name" {
  description = "Hostname of the server"
  type        = string
  default     = "test-machine"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "The machine name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "availability_zone" {
  description = "The availability zone (e.g. eu01-1)"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}[0-9]{2}-[a-zA-Z0-9]+$", var.availability_zone))
    error_message = "The availability zone must follow the STACKIT pattern (e.g., eu01-1, eu01-m)."
  }
}

variable "machine_type" {
  description = "Flavor of the machine"
  type        = string
  default     = "c2i.1"
}

variable "image_id" {
  description = "Image UUID (Default: Debian 12)"
  type        = string
  default     = "c751cde7-e648-4f81-9722-ce9c7848bed0"

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.image_id))
    error_message = "The image_id must be a valid UUID."
  }
}

variable "disk_size" {
  description = "Boot volume size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size >= 1
    error_message = "The disk_size must be at least 1 GB."
  }
}

variable "disk_performance_class" {
  description = "Storage performance class"
  type        = string
  default     = "storage_premium_perf4"
}

variable "user_data" {
  description = "Cloud-init configuration string"
  type        = string
  default     = ""
}

variable "security_enabled" {
  description = "Enable security (port security) on the network interface"
  type        = bool
  default     = false
}
