#!/usr/bin/env bash

set -euo pipefail

IMAGE_URI="${IMAGE_URI:-${1:-}}"
if [[ -z "${IMAGE_URI}" ]]; then
  echo "IMAGE_URI is required" >&2
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR:-$HOME/meshcentral}"
cd "${PROJECT_DIR}"

mkdir -p data backups nginx config

# We assume the server must have the correct env
# Its not our job to set it, but we can check for it and error if its not there
if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required on the host" >&2
  exit 1
fi
export SERVER_IP=$(curl -s http://checkip.amazonaws.com)
if [[ -n "${SERVER_IP:-}" ]]; then
  envsubst < config/config.template.json > data/config.json
fi



if [[ -n "${GHCR_PULL_USERNAME:-}" && -n "${GHCR_PULL_TOKEN:-}" ]]; then
  echo "${GHCR_PULL_TOKEN}" | docker login ghcr.io -u "${GHCR_PULL_USERNAME}" --password-stdin
fi


export IMAGE_URI

previous_image=""
if docker container inspect meshcentral >/dev/null 2>&1; then
  previous_image="$(docker inspect --format '{{.Config.Image}}' meshcentral)"
fi

wait_for_health() {
  local container="$1"
  local attempts="${2:-24}"
  local sleep_seconds="${3:-5}"
  local status=""

  for ((i=1; i<=attempts; i++)); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container}")"

    if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
      return 0
    fi

    if [[ "${status}" == "unhealthy" || "${status}" == "exited" ]]; then
      return 1
    fi

    sleep "${sleep_seconds}"
  done

  return 1
}

rollback() {
  if [[ -z "${previous_image}" || "${previous_image}" == "${IMAGE_URI}" ]]; then
    return
  fi

  echo "Rolling back to ${previous_image}" >&2
  export IMAGE_URI="${previous_image}"
  docker compose up -d meshcentral nginx
}

trap 'echo "Deployment failed" >&2; rollback' ERR

docker compose up -d --remove-orphans --force-recreate

if ! wait_for_health meshcentral; then
  echo "MeshCentral failed health check after deploy: ${IMAGE_URI}" >&2
  docker compose logs --tail=100 meshcentral nginx >&2 || true
  exit 1
fi

trap - ERR

echo "Deployment completed: ${IMAGE_URI}"
