#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENV_DIR="${SCRIPT_DIR}/../terraform/environments/production"

if [ ! -f "${ENV_DIR}/backend.hcl" ]; then
  echo "backend.hcl not found in ${ENV_DIR}. Copy backend.hcl.example and update values." >&2
  exit 1
fi

if [ ! -f "${ENV_DIR}/production.tfvars" ]; then
  echo "production.tfvars not found in ${ENV_DIR}. Copy production.tfvars.example and update secrets." >&2
  exit 1
fi

terraform -chdir="${ENV_DIR}" init -backend-config="backend.hcl"
terraform -chdir="${ENV_DIR}" apply -var-file="production.tfvars" "$@"
