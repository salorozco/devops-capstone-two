#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/destroy_app.sh"
"$ROOT_DIR/scripts/destroy_ci.sh"

echo
echo "DONE"
echo "AWS app and CI stacks destroyed. Docker Hub registry stack was preserved."
