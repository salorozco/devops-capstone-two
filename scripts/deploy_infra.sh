#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
ANSIBLE_DIR="$ROOT_DIR/infra/ansible"
INV_FILE="$ANSIBLE_DIR/inventory/hosts.ini"

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
