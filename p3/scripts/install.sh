#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"

echo "[1/5] Installing system dependencies"
sudo apt-get update -y
sudo apt-get install -y curl git

# Prefer already-installed Docker CE (docker.com). Avoid docker.io — it
# conflicts with containerd.io from the official Docker apt repository.
if ! command -v docker >/dev/null 2>&1; then
	if apt-cache show docker-ce >/dev/null 2>&1; then
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io
	else
		sudo apt-get install -y docker.io
	fi
fi
sudo systemctl enable docker --now
sudo usermod -aG docker "$USER" 2>/dev/null || true

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
