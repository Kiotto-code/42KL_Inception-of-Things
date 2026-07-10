#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"
GITLAB_CHART_VERSION="9.11.8"
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-InsecurePassword1!}"
GITLAB_PROJECT="${GITLAB_PROJECT:-kiotto-iot}"
GITLAB_REPO_URL="http://gitlab-webservice-default.gitlab.svc:8181/root/${GITLAB_PROJECT}.git"

echo "[1/8] Installing system dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl git
sudo systemctl enable docker --now

echo "[2/8] Installing kubectl, k3d, and helm"
curl -fsSL -o kubectl "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
if ! command -v helm >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "[3/8] Creating k3d cluster"
if ! k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
	k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
else
	echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation"
fi

mkdir -p ~/.kube
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context
export KUBECONFIG=~/.kube/config

echo "[4/8] Creating namespaces and installing Argo CD"
kubectl apply -f "$CONFS_DIR/namespace.yaml"
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd

echo "Waiting for Argo CD to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "[5/8] Installing GitLab (Helm)"
kubectl create secret generic gitlab-initial-root-password \
	--from-literal=password="${GITLAB_ROOT_PASSWORD}" \
	-n gitlab \
	--dry-run=client -o yaml | kubectl apply -f -

helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
	-n gitlab \
	--version "${GITLAB_CHART_VERSION}" \
	-f "$CONFS_DIR/gitlab-values.yaml" \
	--timeout 30m \
	--wait

echo "[6/8] Configuring GitLab repository and pushing manifests"
export GITLAB_ROOT_PASSWORD GITLAB_PROJECT
bash "$SCRIPT_DIR/gitlab-setup.sh"

echo "[7/8] Registering GitLab repo with Argo CD"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${GITLAB_REPO_URL}
  username: root
  password: ${GITLAB_ROOT_PASSWORD}
  insecure: "true"
EOF

echo "[8/8] Registering Argo CD application (GitOps sync from GitLab)"
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"

echo ""
echo "Bonus setup complete."
echo ""
echo "GitLab:"
echo "  URL:      http://localhost:8081 (after port-forward)"
echo "  Project:  root/${GITLAB_PROJECT}"
echo "  Username: root"
echo "  Password: ${GITLAB_ROOT_PASSWORD}"
echo ""
echo "Argo CD:"
echo "  Password: ${ARGOCD_PASS}"
echo ""
echo "Useful commands:"
echo "  curl http://localhost:8888/"
echo "  kubectl get pods -n gitlab"
echo "  kubectl get applications -n argocd"
echo "  kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8181"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
