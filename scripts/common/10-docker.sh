#!/usr/bin/env bash
set -euo pipefail

# Installs Docker Engine for Jenkins build workloads.
# Run on the Jenkins agent and optionally on the controller if it also runs builds.
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
ARCH="$(dpkg --print-architecture)"

# Register Docker's official Ubuntu APT repository for the current OS codename.
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install Docker Engine, CLI, Buildx, and Compose plugin.
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin

sudo systemctl enable --now docker

# Allow the default Ubuntu SSH user to run docker commands after reconnecting.
sudo usermod -aG docker ubuntu || true

# If Jenkins is installed on this host, allow Jenkins jobs to use Docker too.
if id jenkins >/dev/null 2>&1; then
  sudo usermod -aG docker jenkins || true
fi

docker --version
echo "Docker installed. Log out and log in again for group changes to apply."
