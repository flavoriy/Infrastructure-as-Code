#!/usr/bin/env bash
set -euo pipefail

# Installs a single-node k3s dev cluster.
# Override PRIVATE_IP, PUBLIC_IP, NODE_NAME, or INSTALL_K3S_CHANNEL if needed.
PRIVATE_IP="${PRIVATE_IP:-10.0.1.12}"
NODE_NAME="${NODE_NAME:-k3s-dev}"
INSTALL_K3S_CHANNEL="${INSTALL_K3S_CHANNEL:-stable}"

# Read EC2 metadata through IMDSv2 so the public EIP can be added as a TLS SAN.
metadata() {
  local path="$1"
  local token
  token="$(curl -fsS -m 2 -X PUT http://169.254.169.254/latest/api/token \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' || true)"
  if [ -n "$token" ]; then
    curl -fsS -m 2 -H "X-aws-ec2-metadata-token: ${token}" "http://169.254.169.254/latest/meta-data/${path}" || true
  fi
}

PUBLIC_IP="${PUBLIC_IP:-$(metadata public-ipv4)}"
TLS_SAN_FLAGS="--tls-san ${PRIVATE_IP}"

# Include the public IP in the API server certificate for local kubectl access.
if [ -n "$PUBLIC_IP" ]; then
  TLS_SAN_FLAGS="${TLS_SAN_FLAGS} --tls-san ${PUBLIC_IP} --node-external-ip ${PUBLIC_IP}"
fi

# Install k3s server with encrypted secrets and a world-readable kubeconfig for lab use.
curl -sfL https://get.k3s.io | \
  sudo env \
    INSTALL_K3S_CHANNEL="$INSTALL_K3S_CHANNEL" \
    INSTALL_K3S_EXEC="server --node-name ${NODE_NAME} --node-ip ${PRIVATE_IP} --advertise-address ${PRIVATE_IP} ${TLS_SAN_FLAGS} --write-kubeconfig-mode 644 --secrets-encryption" \
    sh -

sudo systemctl enable --now k3s
sudo k3s kubectl get nodes -o wide
