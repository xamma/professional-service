#cloud-config
# Docker host bootstrap for ALB + Certbot / ACME DNS-01 workshop
# Target OS: Debian 12 (bookworm)
# Rendered via Terraform templatefile() — variables: start_nginx_test_container

package_update: true
package_upgrade: false
packages:
  - ca-certificates
  - curl
  - gnupg
  - apt-transport-https

runcmd:
  # Add Docker's official GPG key
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  # Add Docker apt repository for Debian
  - >-
    . /etc/os-release &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]
    https://download.docker.com/linux/debian $${VERSION_CODENAME} stable"
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update -y
  # Install Docker Engine + Compose plugin
  - >-
    DEBIAN_FRONTEND=noninteractive apt-get install -y
    docker-ce docker-ce-cli containerd.io
    docker-buildx-plugin docker-compose-plugin
  - systemctl enable --now docker
  # Add default Debian cloud user to docker group
  - usermod -aG docker debian
%{ if start_nginx_test_container ~}
  # Start nginx test container — verify with: curl http://<vm-ip>
  - docker run -d --name nginx-test --restart unless-stopped -p 80:80 nginx:alpine
%{ endif ~}

final_message: "Cloud-init complete after $UPTIME seconds. Docker host is ready."
