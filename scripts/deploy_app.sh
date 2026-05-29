#!/usr/bin/env bash
set -euo pipefail

: "${APP_SERVER_HOST:?APP_SERVER_HOST is required}"
: "${SSH_KEY:?SSH_KEY is required}"

SSH_USER="${SSH_USER:-ubuntu}"
IMAGE_NAME="${IMAGE_NAME:-capstone-nginx}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-capstone-nginx}"
APP_PORT="${APP_PORT:-8081}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/capstone-app}"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"
ARCHIVE="${IMAGE_NAME}.tar"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

docker save "$IMAGE_REF" -o "$ARCHIVE"
scp "${SSH_OPTS[@]}" "$ARCHIVE" "${SSH_USER}@${APP_SERVER_HOST}:${DEPLOY_DIR}/${ARCHIVE}"

ssh "${SSH_OPTS[@]}" "${SSH_USER}@${APP_SERVER_HOST}" "
  set -euo pipefail
  docker load -i '${DEPLOY_DIR}/${ARCHIVE}'
  docker stop '${CONTAINER_NAME}' >/dev/null 2>&1 || true
  docker rm '${CONTAINER_NAME}' >/dev/null 2>&1 || true
  docker run -d --restart unless-stopped --name '${CONTAINER_NAME}' -p '${APP_PORT}:80' '${IMAGE_REF}'
  docker ps --filter name='${CONTAINER_NAME}'
"
