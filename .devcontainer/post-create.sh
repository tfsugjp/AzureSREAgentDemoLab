#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="/workspaces/GlobalAzureDemo2026"

git config --global --add safe.directory "$REPO_ROOT"
git lfs install --skip-repo >/dev/null
az config set extension.use_dynamic_install=yes_without_prompt >/dev/null

if command -v gh >/dev/null 2>&1; then
  if gh extension list 2>/dev/null | grep -qE '^github/gh-copilot\s'; then
    gh extension upgrade github/gh-copilot >/dev/null 2>&1 || true
  else
    gh extension install github/gh-copilot >/dev/null 2>&1 || true
  fi
fi

if ! command -v kubectl >/dev/null 2>&1; then
  az aks install-cli --kubectlinstalllocation /usr/local/bin/kubectl --only-show-errors
fi

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3
  chmod 700 /tmp/get-helm-3
  /tmp/get-helm-3
  rm -f /tmp/get-helm-3
fi

az bicep install --only-show-errors || az bicep upgrade --only-show-errors

cd "$REPO_ROOT"
dotnet restore GlobalAzureDemo2026.slnx

echo "[devcontainer] Tool versions"
dotnet --version
az version --output json | jq -r '"azure-cli=" + .["azure-cli"]'
azd version
docker --version || true
git lfs version || true
gh --version | head -n 1 || true
kubectl version --client --output=yaml | sed -n '1,6p' || true
helm version --short || true
bash --version | head -n 1
python3 --version
