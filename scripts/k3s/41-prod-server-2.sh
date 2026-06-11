#!/usr/bin/env bash
set -euo pipefail

# Joins the second prod k3s server to the first server's embedded-etcd cluster.
# Use the same K3S_TOKEN value that was used on k3s-prod-1.
: "${K3S_TOKEN:?Set K3S_TOKEN to the same token used on k3s-prod-1.}"

PRIVATE_IP="${PRIVATE_IP:-10.0.2.11}"
NODE_NAME="${NODE_NAME:-k3s-prod-2}"
SERVER_URL="${SERVER_URL:-https://10.0.2.10:6443}"
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
TLS_SAN_FLAGS="--tls-san 10.0.2.10 --tls-san 10.0.2.11 --tls-san 10.0.2.12"

# Include the public IP in the API server certificate for local kubectl access.
if [ -n "$PUBLIC_IP" ]; then
  TLS_SAN_FLAGS="${TLS_SAN_FLAGS} --tls-san ${PUBLIC_IP} --node-external-ip ${PUBLIC_IP}"
fi

# --server points this node at the first prod server so it joins the cluster.
curl -sfL https://get.k3s.io | \
  K3S_TOKEN="$K3S_TOKEN" \
  INSTALL_K3S_CHANNEL="$INSTALL_K3S_CHANNEL" \
  INSTALL_K3S_EXEC="server --server ${SERVER_URL} --node-name ${NODE_NAME} --node-ip ${PRIVATE_IP} --advertise-address ${PRIVATE_IP} ${TLS_SAN_FLAGS} --write-kubeconfig-mode 644 --secrets-encryption" \
  sh -

sudo systemctl enable --now k3s
sudo k3s kubectl get nodes -o wide
