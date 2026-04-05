#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="/workspaces/GlobalAzureDemo2026"

git config --global --add safe.directory "$REPO_ROOT"
az config set extension.use_dynamic_install=yes_without_prompt >/dev/null

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