#!/usr/bin/env bash
set -euo pipefail

: "${APP_SERVER_HOST:?APP_SERVER_HOST is required}"
: "${SSH_KEY:?SSH_KEY is required}"
: "${IMAGE_REPOSITORY:?IMAGE_REPOSITORY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}"

SSH_USER="${SSH_USER:-ubuntu}"
CONTAINER_NAME="${CONTAINER_NAME:-capstone-nginx}"
APP_PORT="${APP_PORT:-8081}"
IMAGE_REF="${IMAGE_REPOSITORY}:${IMAGE_TAG}"
DOCKERHUB_TOKEN_B64="$(printf '%s' "$DOCKERHUB_TOKEN" | base64 -w0)"

REMOTE_IMAGE_REF="$(printf '%q' "$IMAGE_REF")"
REMOTE_CONTAINER_NAME="$(printf '%q' "$CONTAINER_NAME")"
REMOTE_APP_PORT="$(printf '%q' "$APP_PORT")"
REMOTE_DOCKERHUB_USERNAME="$(printf '%q' "$DOCKERHUB_USERNAME")"
REMOTE_DOCKERHUB_TOKEN_B64="$(printf '%q' "$DOCKERHUB_TOKEN_B64")"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

ssh "${SSH_OPTS[@]}" "${SSH_USER}@${APP_SERVER_HOST}" "bash -s" <<REMOTE
  set -euo pipefail

  IMAGE_REF=$REMOTE_IMAGE_REF
  CONTAINER_NAME=$REMOTE_CONTAINER_NAME
  APP_PORT=$REMOTE_APP_PORT
  DOCKERHUB_USERNAME=$REMOTE_DOCKERHUB_USERNAME
  DOCKERHUB_TOKEN_B64=$REMOTE_DOCKERHUB_TOKEN_B64

  DOCKERHUB_TOKEN="\$(printf '%s' "\$DOCKERHUB_TOKEN_B64" | base64 -d)"
  trap 'docker logout >/dev/null 2>&1 || true' EXIT

  printf '%s\n' "\$DOCKERHUB_TOKEN" | docker login -u "\$DOCKERHUB_USERNAME" --password-stdin
  unset DOCKERHUB_TOKEN DOCKERHUB_TOKEN_B64

  docker pull "\$IMAGE_REF"
  docker stop "\$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm "\$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run -d --restart unless-stopped --name "\$CONTAINER_NAME" -p "\$APP_PORT:80" "\$IMAGE_REF"
  docker ps --filter "name=\$CONTAINER_NAME"
REMOTE
