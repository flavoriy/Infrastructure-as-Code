#!/usr/bin/env bash
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"

if ! command -v "$KUBECTL" >/dev/null 2>&1; then
  KUBECTL="sudo k3s kubectl"
fi

$KUBECTL create namespace argocd --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
$KUBECTL -n argocd rollout status deploy/argocd-server --timeout=300s

echo "ArgoCD installed."
echo "Initial admin password:"
$KUBECTL -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo "Use port-forward for first login:"
echo "$KUBECTL -n argocd port-forward svc/argocd-server 8080:443"

