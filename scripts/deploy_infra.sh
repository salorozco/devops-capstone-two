#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
ANSIBLE_DIR="$ROOT_DIR/infra/ansible"
INV_FILE="$ANSIBLE_DIR/inventory/hosts.ini"
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

export DOCKER_USERNAME="$DOCKERHUB_USERNAME"
export DOCKER_PASSWORD="$DOCKERHUB_TOKEN"
export TF_VAR_dockerhub_namespace="${DOCKERHUB_NAMESPACE:-$DOCKERHUB_USERNAME}"
export TF_VAR_dockerhub_repository_name="${DOCKERHUB_REPOSITORY_NAME:-capstone-nginx}"

echo "== Terraform: init/plan/apply =="
cd "$TF_DIR"
terraform init -upgrade
terraform apply -auto-approve

echo
echo "== Verify inventory generated =="
if [[ ! -f "$INV_FILE" ]]; then
  echo "ERROR: inventory not found at $INV_FILE"
  exit 1
fi
echo "Inventory:"
sed -n '1,120p' "$INV_FILE"

echo
echo "== Wait for SSH (instances still booting sometimes) =="
# Try ping module a few times; Ubuntu cloud-init can take ~30-90s
cd "$ANSIBLE_DIR"
for i in {1..12}; do
  if ansible -i "$INV_FILE" all -m ping >/dev/null 2>&1; then
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
