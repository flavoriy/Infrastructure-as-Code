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

install_k3s_dev() {
  PRIVATE_IP="${PRIVATE_IP:-10.0.1.12}"
  NODE_NAME="${NODE_NAME:-k3s-dev}"
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
  echo "Installing Argo CD into k3s dev cluster..."
  sudo k3s kubectl create namespace argocd --dry-run=client -o yaml | sudo k3s kubectl apply -f -
  sudo k3s kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  sudo k3s kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

  echo "Applying TikTo Argo CD dev application..."
  sudo k3s kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/applications/tikto-dev.yaml || true
}

echo "Setting up k3s_dev..."
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-k3s-dev}"
PRIVATE_IP="${PRIVATE_IP:-10.0.1.12}"
NODE_NAME="${NODE_NAME:-k3s-dev}"
INSTALL_ARGOCD="${INSTALL_ARGOCD:-true}"

setup_base
install_k3s_dev

if [ "$INSTALL_ARGOCD" = "true" ]; then
  install_argocd
fi

cat <<'EOF'

k3s_dev setup completed successfully with k3s & Argo CD.

Verify:
  sudo k3s kubectl get nodes -o wide
  sudo k3s kubectl get pods -A
  sudo k3s kubectl get applications -n argocd
EOF
