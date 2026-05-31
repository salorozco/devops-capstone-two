#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_BASE_DIR="$ROOT_DIR/infra/terraform"
TF_VAR_FILE="$TF_BASE_DIR/terraform.tfvars"
CI_STACK="$TF_BASE_DIR/stacks/ci"
APP_STACK="$TF_BASE_DIR/stacks/app"

tf_common_args=()
if [[ -f "$TF_VAR_FILE" ]]; then
  tf_common_args+=("-var-file=$TF_VAR_FILE")
fi

ci_security_group_id="$(terraform -chdir="$CI_STACK" output -raw ci_security_group_id 2>/dev/null || true)"
if [[ -z "$ci_security_group_id" ]]; then
  ci_security_group_id="sg-00000000000000000"
fi

echo "== Destroy app stack =="
terraform -chdir="$APP_STACK" init -upgrade
terraform -chdir="$APP_STACK" destroy -auto-approve "${tf_common_args[@]}" -var "ci_security_group_id=$ci_security_group_id"
