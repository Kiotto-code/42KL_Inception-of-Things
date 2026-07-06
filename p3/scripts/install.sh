#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"

echo "[1/5] Installing system dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl git
sudo systemctl enable docker --now

echo "[2/5] Installing kubectl and k3d"
curl -fsSL -o kubectl "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "[3/5] Creating k3d cluster"
if ! k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
	k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
else
	echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation"
fi

mkdir -p ~/.kube
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context
export KUBECONFIG=~/.kube/config

echo "[4/5] Creating namespaces and installing Argo CD"
kubectl apply -f "$CONFS_DIR/namespace.yaml"
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd

echo "Waiting for Argo CD to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "[5/5] Registering Argo CD application (GitOps sync)"
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"

echo ""
echo "Setup complete."
echo ""
echo "Argo CD admin password: ${ARGOCD_PASS}"
echo ""
echo "Ensure p3/confs/app is pushed to GitHub (p2 branch) before evaluation."
echo "Argo CD will auto-sync wil42/playground:v1 into the dev namespace."
echo ""
echo "Useful commands:"
echo "  curl http://localhost:8888/"
echo "  kubectl get applications -n argocd"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Evaluation flow:"
echo "  1. curl http://localhost:8888/  -> confirm v1"
echo "  2. Change image tag to v2 in p3/confs/app/deployment.yaml, then git push"
echo "  3. Wait for Argo CD status: Synced / Healthy"
echo "  4. curl http://localhost:8888/  -> confirm v2"
