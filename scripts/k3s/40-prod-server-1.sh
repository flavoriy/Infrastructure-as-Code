#!/usr/bin/env bash
set -euo pipefail

# Initializes the first prod k3s server with embedded etcd.
# K3S_TOKEN must be shared with the second prod server.
: "${K3S_TOKEN:?Set K3S_TOKEN before running this script. Example: export K3S_TOKEN=$(openssl rand -hex 32)}"

PRIVATE_IP="${PRIVATE_IP:-10.0.1.13}"
NODE_NAME="${NODE_NAME:-k3s-prod-1}"
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
TLS_SAN_FLAGS="--tls-san 10.0.1.13 --tls-san 10.0.1.14"

# Include the public IP in the API server certificate for local kubectl access.
if [ -n "$PUBLIC_IP" ]; then
  TLS_SAN_FLAGS="${TLS_SAN_FLAGS} --tls-san ${PUBLIC_IP} --node-external-ip ${PUBLIC_IP}"
fi

# --cluster-init creates the embedded-etcd cluster on the first server.
curl -sfL https://get.k3s.io | \
  K3S_TOKEN="$K3S_TOKEN" \
  INSTALL_K3S_CHANNEL="$INSTALL_K3S_CHANNEL" \
  INSTALL_K3S_EXEC="server --cluster-init --node-name ${NODE_NAME} --node-ip ${PRIVATE_IP} --advertise-address ${PRIVATE_IP} ${TLS_SAN_FLAGS} --write-kubeconfig-mode 644 --secrets-encryption" \
  sh -

sudo systemctl enable --now k3s
sudo k3s kubectl get nodes -o wide
