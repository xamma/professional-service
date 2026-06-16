#cloud-config

package_update: true
package_upgrade: false
packages:
  - ca-certificates
  - curl
  - gnupg

write_files:
  - path: /opt/install-docker.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc

      . /etc/os-release
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce docker-ce-cli containerd.io docker-compose-plugin

      systemctl enable --now docker
      usermod -aG docker debian
      docker run -d --name nginx --restart unless-stopped -p 80:80 nginx:alpine

runcmd:
  - /opt/install-docker.sh

final_message: "Cloud-init complete after $UPTIME seconds."
