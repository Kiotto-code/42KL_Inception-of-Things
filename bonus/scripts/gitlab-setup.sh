#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-InsecurePassword1!}"
GITLAB_PROJECT="${GITLAB_PROJECT:-kiotto-iot}"
GITLAB_PORT="${GITLAB_PORT:-8081}"
GITLAB_API="http://localhost:${GITLAB_PORT}/api/v4"
GITLAB_AUTH="root:${GITLAB_ROOT_PASSWORD}"

echo "Waiting for GitLab webservice..."
kubectl wait --for=condition=available --timeout=1800s \
	deployment/gitlab-webservice-default -n gitlab

echo "Starting temporary GitLab port-forward on localhost:${GITLAB_PORT}"
kubectl port-forward "svc/gitlab-webservice-default" -n gitlab "${GITLAB_PORT}:8181" >/tmp/gitlab-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill "${PF_PID}" 2>/dev/null || true' EXIT

for i in $(seq 1 60); do
	if curl -sf "http://localhost:${GITLAB_PORT}/-/readiness" >/dev/null 2>&1; then
		break
	fi
	sleep 5
	if [ "$i" -eq 60 ]; then
		echo "GitLab did not become ready in time"
		exit 1
	fi
done

PROJECT_PATH="root/${GITLAB_PROJECT}"
PROJECT_ID="$(curl -sf --user "${GITLAB_AUTH}" \
	"${GITLAB_API}/projects/root%2F${GITLAB_PROJECT}" 2>/dev/null \
	| sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1 || true)"

if [ -z "${PROJECT_ID}" ]; then
	echo "Creating GitLab project '${GITLAB_PROJECT}'"
	PROJECT_ID="$(curl -sf --request POST "${GITLAB_API}/projects" \
		--user "${GITLAB_AUTH}" \
		--data "name=${GITLAB_PROJECT}&visibility=public" \
		| sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)"
else
	echo "GitLab project '${PROJECT_PATH}' already exists (id=${PROJECT_ID})"
fi

echo "Removing default branch protection on main"
curl -sf --request DELETE --user "${GITLAB_AUTH}" \
	"${GITLAB_API}/projects/${PROJECT_ID}/protected_branches/main" >/dev/null 2>&1 || true

WORKDIR="$(mktemp -d)"
REPO_URL="http://root:${GITLAB_ROOT_PASSWORD}@localhost:${GITLAB_PORT}/${PROJECT_PATH}.git"

if git ls-remote "${REPO_URL}" main 2>/dev/null | grep -q main; then
	echo "Repository already has commits, updating manifests"
	git clone "${REPO_URL}" "${WORKDIR}/repo"
	cp -r "${CONFS_DIR}/app" "${WORKDIR}/repo/"
	cd "${WORKDIR}/repo"
	git add app/
	if git diff --cached --quiet; then
		echo "Manifests already up to date, skipping push"
	else
		git commit -m "Update app manifests (v1)"
		git push origin main
	fi
else
	echo "Initializing repository with app manifests"
	cp -r "${CONFS_DIR}/app" "${WORKDIR}/"
	cd "${WORKDIR}"
	git init -b main
	git config user.email "root@localhost"
	git config user.name "root"
	git add .
	git commit -m "Initial app manifests (v1)"
	git remote add origin "${REPO_URL}"
	git push -u origin main
fi

echo "GitLab repository ${PROJECT_PATH} is ready with app/ manifests"
