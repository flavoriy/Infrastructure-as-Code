#!/usr/bin/env bash
set -euo pipefail

# Common bootstrap for every EC2 node.
# It prepares Ubuntu with baseline tools and kernel settings required by k3s.
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-}"

# Optional: set a stable hostname when running the script manually.
if [ -n "$HOSTNAME_OVERRIDE" ]; then
  sudo hostnamectl set-hostname "$HOSTNAME_OVERRIDE"
fi

# Keep logs and timestamps aligned with the project team's local timezone.
sudo timedatectl set-timezone Asia/Ho_Chi_Minh || true

# Install common troubleshooting and package-management tools used by later scripts.
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  dnsutils \
  git \
  gnupg \
  htop \
  jq \
  lsb-release \
  net-tools \
  openssl \
  unzip \
  wget

# Kubernetes requires swap to be disabled. Keep the command tolerant so reruns are safe.
sudo swapoff -a || true
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

# Load container networking kernel modules at boot.
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay || true
sudo modprobe br_netfilter || true

# Enable packet forwarding and bridge netfilter so pods/services can route correctly.
cat <<'EOF' | sudo tee /etc/sysctl.d/99-k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system >/dev/null

echo "Base OS configuration completed."
