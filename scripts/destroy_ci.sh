#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_BASE_DIR="$ROOT_DIR/infra/terraform"
TF_VAR_FILE="$TF_BASE_DIR/terraform.tfvars"
CI_STACK="$TF_BASE_DIR/stacks/ci"

tf_common_args=()
if [[ -f "$TF_VAR_FILE" ]]; then
  tf_common_args+=("-var-file=$TF_VAR_FILE")
fi

echo "== Destroy CI stack =="
echo "This expects the app stack to already be destroyed."
terraform -chdir="$CI_STACK" init -upgrade
terraform -chdir="$CI_STACK" destroy -auto-approve "${tf_common_args[@]}"
