#!/usr/bin/env bash
set -euo pipefail

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
ARCH="$(dpkg --print-architecture)"

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu || true

if id jenkins >/dev/null 2>&1; then
  sudo usermod -aG docker jenkins || true
fi

docker --version
echo "Docker installed. Log out and log in again for group changes to apply."

