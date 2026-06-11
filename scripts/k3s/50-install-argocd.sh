#!/usr/bin/env bash
set -euo pipefail

# Installs Argo CD into the current Kubernetes cluster.
# KUBECTL can be overridden, otherwise the script falls back to k3s kubectl.
KUBECTL="${KUBECTL:-kubectl}"

if ! command -v "$KUBECTL" >/dev/null 2>&1; then
  KUBECTL="sudo k3s kubectl"
fi

# Create the namespace idempotently and apply the official stable Argo CD manifests.
$KUBECTL create namespace argocd --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait until the API server deployment is ready before printing login details.
$KUBECTL -n argocd rollout status deploy/argocd-server --timeout=300s

echo "ArgoCD installed."
echo "Initial admin password:"
$KUBECTL -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo "Use port-forward for first login:"
echo "$KUBECTL -n argocd port-forward svc/argocd-server 8080:443"
