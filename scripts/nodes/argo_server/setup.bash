#!/usr/bin/env bash
set -euo pipefail

setup_base() {
  if [ -n "${HOSTNAME_OVERRIDE:-}" ]; then
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
net.ipv6.conf.all.forwarding = 1
EOF

  sudo sysctl --system >/dev/null

  echo "Base OS configuration completed."
}

metadata() {
  local path="$1"
  local token
  token="$(curl -fsS -m 2 -X PUT http://169.254.169.254/latest/api/token \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' || true)"
  if [ -n "$token" ]; then
    curl -fsS -m 2 -H "X-aws-ec2-metadata-token: ${token}" "http://169.254.169.254/latest/meta-data/${path}" || true
  fi
}

install_k3s_argo() {
  PRIVATE_IP="${PRIVATE_IP:-10.0.1.10}"
  NODE_NAME="${NODE_NAME:-argo-server}"
  INSTALL_K3S_CHANNEL="${INSTALL_K3S_CHANNEL:-stable}"
  PUBLIC_IP="${PUBLIC_IP:-$(metadata public-ipv4)}"
  TLS_SAN_FLAGS="--tls-san ${PRIVATE_IP}"

  if [ -n "$PUBLIC_IP" ]; then
    TLS_SAN_FLAGS="${TLS_SAN_FLAGS} --tls-san ${PUBLIC_IP} --node-external-ip ${PUBLIC_IP}"
  fi

  curl -sfL https://get.k3s.io | \
    sudo env \
      INSTALL_K3S_CHANNEL="$INSTALL_K3S_CHANNEL" \
      INSTALL_K3S_EXEC="server --node-name ${NODE_NAME} --node-ip ${PRIVATE_IP} --advertise-address ${PRIVATE_IP} ${TLS_SAN_FLAGS} --write-kubeconfig-mode 644 --secrets-encryption" \
      sh -

  sudo systemctl enable --now k3s
  sudo k3s kubectl get nodes -o wide
}

install_argocd() {
  echo "Installing Argo CD Server..."
  sudo k3s kubectl create namespace argocd --dry-run=client -o yaml | sudo k3s kubectl apply -f -
  sudo k3s kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  sudo k3s kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

  echo "Applying TikTo Argo CD applications..."
  sudo k3s kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/applications/tikto-dev.yaml || true
  sudo k3s kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/applications/tikto-prod.yaml || true
}

install_tailscale() {
  echo "Installing Tailscale & configuring Subnet Router for AWS VPC (10.0.0.0/16)..."
  curl -fsSL https://tailscale.com/install.sh | sh

  # Auto-start Tailscale service
  sudo systemctl enable --now tailscaled

  # Check if TAILSCALE_AUTHKEY is passed in env
  if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    echo "Authenticating Tailscale with Auth Key and advertising subnet 10.0.0.0/16..."
    sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --advertise-routes=10.0.0.0/16 --accept-dns=false
  else
    echo "Tailscale installed successfully."
    echo "To connect to your Tailscale tailnet and advertise the AWS VPC Subnet, run:"
    echo "  sudo tailscale up --advertise-routes=10.0.0.0/16 --accept-dns=false"
  fi
}

echo "Setting up argo_server with K3s, Argo CD, and Tailscale Subnet Router..."
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-argo-server}"
PRIVATE_IP="${PRIVATE_IP:-10.0.1.10}"
NODE_NAME="${NODE_NAME:-argo-server}"

setup_base
install_k3s_argo
install_argocd
install_tailscale

cat <<'EOF'

argo_server setup completed successfully with k3s, Argo CD, and Tailscale Subnet Router.

Verify:
  sudo k3s kubectl get nodes -o wide
  sudo k3s kubectl get pods -n argocd
  sudo tailscale status
EOF
