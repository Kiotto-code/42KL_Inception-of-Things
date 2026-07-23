#!/bin/bash
set -eu

CLUSTER_NAME="iot-cluster"

echo "[1/4] Deleting k3d cluster '${CLUSTER_NAME}' (Argo CD, namespaces, apps)"
if command -v k3d >/dev/null 2>&1; then
	if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
		k3d cluster delete "$CLUSTER_NAME"
	else
		echo "Cluster '${CLUSTER_NAME}' not found, skipping"
	fi
else
	echo "k3d not installed, skipping cluster delete"
fi

echo "[2/4] Removing kubectl"
if [ -f /usr/local/bin/kubectl ]; then
	sudo rm -f /usr/local/bin/kubectl
	echo "Removed /usr/local/bin/kubectl"
else
	echo "kubectl not found, skipping"
fi

echo "[3/4] Removing k3d"
if [ -f /usr/local/bin/k3d ]; then
	sudo rm -f /usr/local/bin/k3d
	echo "Removed /usr/local/bin/k3d"
else
	echo "k3d not found, skipping"
fi

echo "[4/4] Cleaning k3d/kubeconfig leftovers"
rm -rf "${HOME}/.config/k3d" 2>/dev/null || true
rm -f "${HOME}/.kube/config" 2>/dev/null || true
# Drop empty .kube dir only if nothing remains
if [ -d "${HOME}/.kube" ] && [ -z "$(ls -A "${HOME}/.kube" 2>/dev/null)" ]; then
	rmdir "${HOME}/.kube" 2>/dev/null || true
fi

echo ""
echo "Cleanup complete."
echo "Kept: Docker, curl, git"
echo "Removed: k3d cluster '${CLUSTER_NAME}', kubectl, k3d, related kubeconfig"
