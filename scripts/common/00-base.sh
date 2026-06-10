#!/usr/bin/env bash
set -euo pipefail

HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-}"

if [ -n "$HOSTNAME_OVERRIDE" ]; then
  sudo hostnamectl set-hostname "$HOSTNAME_OVERRIDE"
fi

sudo timedatectl set-timezone Asia/Ho_Chi_Minh || true

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

sudo swapoff -a || true
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay || true
sudo modprobe br_netfilter || true

cat <<'EOF' | sudo tee /etc/sysctl.d/99-k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system >/dev/null

echo "Base OS configuration completed."

