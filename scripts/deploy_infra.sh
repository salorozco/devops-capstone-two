#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_BASE_DIR="$ROOT_DIR/infra/terraform"
TF_VAR_FILE="$TF_BASE_DIR/terraform.tfvars"
REGISTRY_STACK="$TF_BASE_DIR/stacks/registry"
CI_STACK="$TF_BASE_DIR/stacks/ci"
APP_STACK="$TF_BASE_DIR/stacks/app"
ANSIBLE_DIR="$ROOT_DIR/infra/ansible"
INV_FILE="$ANSIBLE_DIR/inventory/aws_ec2.yml"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

if [[ -z "${JENKINS_ADMIN_PASSWORD:-}" ]]; then
  echo "ERROR: JENKINS_ADMIN_PASSWORD is required."
  echo "Set it in your shell or in $ENV_FILE"
  exit 1
fi

if [[ -z "${GITHUB_USERNAME:-}" ]]; then
  echo "ERROR: GITHUB_USERNAME is required."
  echo "Set it in your shell or in $ENV_FILE"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is required."
  echo "Set it in your shell or in $ENV_FILE"
  exit 1
fi

if [[ -z "${DOCKERHUB_USERNAME:-}" ]]; then
  echo "ERROR: DOCKERHUB_USERNAME is required."
  echo "Set it in your shell or in $ENV_FILE"
  exit 1
fi

if [[ -z "${DOCKERHUB_TOKEN:-}" ]]; then
  echo "ERROR: DOCKERHUB_TOKEN is required."
  echo "Set it in your shell or in $ENV_FILE"
  exit 1
fi

if ! /usr/bin/python3 - <<'PY' >/dev/null 2>&1
import boto3
import botocore
PY
then
  echo "ERROR: Ansible AWS dynamic inventory requires boto3 and botocore for /usr/bin/python3."
  echo "Install them with:"
  echo "  /usr/bin/python3 -m pip install --user -r $ANSIBLE_DIR/requirements.txt"
  exit 1
fi

export DOCKER_USERNAME="$DOCKERHUB_USERNAME"
export DOCKER_PASSWORD="$DOCKERHUB_TOKEN"
export TF_VAR_dockerhub_namespace="${DOCKERHUB_NAMESPACE:-$DOCKERHUB_USERNAME}"
export TF_VAR_dockerhub_repository_name="${DOCKERHUB_REPOSITORY_NAME:-capstone-nginx}"

tf_common_args=()
if [[ -f "$TF_VAR_FILE" ]]; then
  tf_common_args+=("-var-file=$TF_VAR_FILE")
fi

tf_apply() {
  local stack_dir="$1"
  shift

  echo
  echo "== Terraform apply: ${stack_dir#$TF_BASE_DIR/stacks/} =="
  terraform -chdir="$stack_dir" init -upgrade
  terraform -chdir="$stack_dir" apply -auto-approve "$@"
}

tf_apply "$REGISTRY_STACK"
image_repository="$(terraform -chdir="$REGISTRY_STACK" output -raw image_repository)"

tf_apply "$CI_STACK" "${tf_common_args[@]}"
ci_security_group_id="$(terraform -chdir="$CI_STACK" output -raw ci_security_group_id)"

tf_apply "$APP_STACK" "${tf_common_args[@]}" -var "ci_security_group_id=$ci_security_group_id"

echo
echo "== Stack outputs =="
echo "Docker image repository: $image_repository"
echo
echo "CI:"
terraform -chdir="$CI_STACK" output
echo
echo "App:"
terraform -chdir="$APP_STACK" output

echo
echo "== Verify dynamic inventory =="
if [[ ! -f "$INV_FILE" ]]; then
  echo "ERROR: dynamic inventory not found at $INV_FILE"
  exit 1
fi
cd "$ANSIBLE_DIR"
ansible-inventory -i "$INV_FILE" --graph

echo
echo "== Wait for SSH (instances still booting sometimes) =="
for i in {1..12}; do
  if ansible -i "$INV_FILE" all --list-hosts 2>/dev/null | grep -q 'hosts (3)' \
    && ansible -i "$INV_FILE" all -m ping >/dev/null 2>&1; then
    echo "SSH ready"
    break
  fi
  echo "Not ready yet... retry $i/12"
  sleep 10
done

echo
echo "== Run Ansible playbook =="
ansible-playbook -i "$INV_FILE" site.yml

echo
echo "DONE"
