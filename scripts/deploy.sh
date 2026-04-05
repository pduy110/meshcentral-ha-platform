#!/usr/bin/env bash

set -euo pipefail

IMAGE_URI="${IMAGE_URI:-${1:-}}"
MESH_FQDN="${MESH_FQDN:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
TRUSTED_PROXY="${TRUSTED_PROXY:-nginx,127.0.0.1,::1}"
CERT_URL="${CERT_URL:-https://nginx:443/}"
PROJECT_DIR="${PROJECT_DIR:-$HOME/meshcentral}"
CERTBOT_WEBROOT_HOST="${CERTBOT_WEBROOT_HOST:-${PROJECT_DIR}/.certbot/www}"
LETSENCRYPT_DIR_HOST="${LETSENCRYPT_DIR_HOST:-${PROJECT_DIR}/.certbot/conf}"
LETSENCRYPT_LIB_HOST="${LETSENCRYPT_LIB_HOST:-${PROJECT_DIR}/.certbot/lib}"
CERTBOT_WEBROOT="${CERTBOT_WEBROOT:-/var/www/certbot}"
LETSENCRYPT_DIR="${LETSENCRYPT_DIR:-/etc/letsencrypt}"
DEPLOY_STATE_DIR="${PROJECT_DIR}/.deploy-state"
TLS_BOOTSTRAPPED_MARKER="${DEPLOY_STATE_DIR}/tls_bootstrapped"
LAST_SUCCESSFUL_IMAGE_FILE="${DEPLOY_STATE_DIR}/last_successful_image"
ROLLBACK_IN_PROGRESS=0
previous_image=""

require_env() {
  if [[ -z "${IMAGE_URI}" ]]; then
    echo "IMAGE_URI is required" >&2
    exit 1
  fi

  if [[ -z "${MESH_FQDN}" ]]; then
    echo "MESH_FQDN is required" >&2
    exit 1
  fi

  if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
    echo "LETSENCRYPT_EMAIL is required" >&2
    exit 1
  fi
}

ensure_host_prereqs() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required on the host" >&2
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose is required on the host" >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required on the host" >&2
    exit 1
  fi
}

ensure_runtime_dirs() {
  mkdir -p \
    "${PROJECT_DIR}/data" \
    "${PROJECT_DIR}/backups" \
    "${PROJECT_DIR}/nginx" \
    "${PROJECT_DIR}/config" \
    "${CERTBOT_WEBROOT_HOST}" \
    "${LETSENCRYPT_DIR_HOST}" \
    "${LETSENCRYPT_LIB_HOST}" \
    "${DEPLOY_STATE_DIR}"
}

require_supporting_scripts() {
  local missing=0

  for path in \
    "scripts/render_nginx_config.sh" \
    "scripts/render_meshcentral_config.sh"; do
    if [[ ! -f "${PROJECT_DIR}/${path}" ]]; then
      echo "Missing required helper: ${path}" >&2
      missing=1
    fi
  done

  if [[ "${missing}" -ne 0 ]]; then
    exit 1
  fi
}

ghcr_login_if_needed() {
  if [[ -n "${GHCR_PULL_USERNAME:-}" && -n "${GHCR_PULL_TOKEN:-}" ]]; then
    echo "${GHCR_PULL_TOKEN}" | docker login ghcr.io -u "${GHCR_PULL_USERNAME}" --password-stdin
  fi
}

read_previous_image() {
  previous_image=""

  if [[ -s "${LAST_SUCCESSFUL_IMAGE_FILE}" ]]; then
    previous_image="$(<"${LAST_SUCCESSFUL_IMAGE_FILE}")"
    return
  fi

  local container_id=""
  container_id="$(docker compose ps -q meshcentral 2>/dev/null || true)"

  if [[ -n "${container_id}" ]]; then
    previous_image="$(docker inspect --format '{{.Config.Image}}' "${container_id}" 2>/dev/null || true)"
  fi
}

render_bootstrap_nginx() {
  bash "${PROJECT_DIR}/scripts/render_nginx_config.sh" bootstrap
}

render_https_nginx() {
  bash "${PROJECT_DIR}/scripts/render_nginx_config.sh" https
}

render_meshcentral_config() {
  bash "${PROJECT_DIR}/scripts/render_meshcentral_config.sh"
}

start_nginx_if_needed() {
  docker compose up -d --remove-orphans nginx
}

validate_and_reload_nginx() {
  docker compose exec -T nginx nginx -t
  docker compose exec -T nginx nginx -s reload
}

issue_first_certificate() {
  docker run --rm \
    -v "${LETSENCRYPT_DIR_HOST}:${LETSENCRYPT_DIR}" \
    -v "${LETSENCRYPT_LIB_HOST}:/var/lib/letsencrypt" \
    -v "${CERTBOT_WEBROOT_HOST}:${CERTBOT_WEBROOT}" \
    certbot/certbot certonly --webroot -w "${CERTBOT_WEBROOT}" \
    --email "${LETSENCRYPT_EMAIL}" --agree-tos --no-eff-email --non-interactive \
    --keep-until-expiring \
    -d "${MESH_FQDN}"
}

verify_cert_from_nginx() {
  docker compose exec -T nginx test -r "/etc/letsencrypt/live/${MESH_FQDN}/fullchain.pem"
  docker compose exec -T nginx test -r "/etc/letsencrypt/live/${MESH_FQDN}/privkey.pem"
}

start_meshcentral() {
  docker compose up -d --remove-orphans --force-recreate meshcentral
}

wait_for_meshcentral_health() {
  local attempts="${1:-24}"
  local sleep_seconds="${2:-5}"
  local container_id=""
  local health_status=""
  local container_status=""

  container_id="$(docker compose ps -q meshcentral)"
  if [[ -z "${container_id}" ]]; then
    echo "MeshCentral container could not be located via docker compose" >&2
    return 1
  fi

  for ((i=1; i<=attempts; i++)); do
    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container_id}")"
    container_status="$(docker inspect --format '{{.State.Status}}' "${container_id}")"

    if [[ -n "${health_status}" ]]; then
      if [[ "${health_status}" == "healthy" ]]; then
        return 0
      fi

      if [[ "${health_status}" == "unhealthy" || "${container_status}" == "exited" ]]; then
        return 1
      fi
    elif [[ "${container_status}" == "running" ]]; then
      return 0
    elif [[ "${container_status}" == "exited" ]]; then
      return 1
    fi

    sleep "${sleep_seconds}"
  done

  return 1
}

wait_for_https_reachability() {
  local attempts="${1:-24}"
  local sleep_seconds="${2:-5}"

  for ((i=1; i<=attempts; i++)); do
    if curl --silent --show-error --fail --head \
      --resolve "${MESH_FQDN}:443:127.0.0.1" \
      "https://${MESH_FQDN}/" >/dev/null; then
      return 0
    fi

    sleep "${sleep_seconds}"
  done

  return 1
}

write_last_successful_image() {
  printf '%s\n' "${IMAGE_URI}" > "${LAST_SUCCESSFUL_IMAGE_FILE}"
}

write_bootstrap_state() {
  touch "${TLS_BOOTSTRAPPED_MARKER}"
  write_last_successful_image
}

rollback() {
  if [[ "${ROLLBACK_IN_PROGRESS}" -eq 1 ]]; then
    return
  fi

  if [[ -z "${previous_image}" || "${previous_image}" == "${IMAGE_URI}" ]]; then
    echo "No previous successful image available for rollback." >&2
    return
  fi

  ROLLBACK_IN_PROGRESS=1
  trap - ERR

  echo "Rolling back to ${previous_image}" >&2
  export IMAGE_URI="${previous_image}"

  render_https_nginx
  start_nginx_if_needed
  validate_and_reload_nginx
  render_meshcentral_config
  start_meshcentral
}

log_failure_context() {
  docker compose logs --tail=100 meshcentral nginx >&2 || true
}

fresh_host_deploy() {
  echo "Fresh host detected. Running first-time TLS bootstrap." >&2

  render_bootstrap_nginx
  start_nginx_if_needed
  issue_first_certificate
  verify_cert_from_nginx
  render_https_nginx
  validate_and_reload_nginx
  render_meshcentral_config
  start_meshcentral

  if ! wait_for_meshcentral_health; then
    echo "MeshCentral failed health checks during fresh-host bootstrap." >&2
    log_failure_context
    exit 1
  fi

  if ! wait_for_https_reachability; then
    echo "HTTPS did not become reachable during fresh-host bootstrap." >&2
    log_failure_context
    exit 1
  fi

  write_bootstrap_state
}

steady_state_deploy() {
  echo "Bootstrapped host detected. Running steady-state deploy." >&2

  read_previous_image
  trap 'echo "Deployment failed" >&2; rollback; log_failure_context' ERR

  render_https_nginx
  start_nginx_if_needed
  validate_and_reload_nginx
  render_meshcentral_config
  start_meshcentral

  if ! wait_for_meshcentral_health; then
    echo "MeshCentral failed health checks after deploy: ${IMAGE_URI}" >&2
    exit 1
  fi

  if ! wait_for_https_reachability; then
    echo "HTTPS did not become reachable after deploy: ${IMAGE_URI}" >&2
    exit 1
  fi

  trap - ERR
  write_last_successful_image
}

main() {
  require_env
  ensure_host_prereqs
  export IMAGE_URI MESH_FQDN LETSENCRYPT_EMAIL TRUSTED_PROXY CERT_URL PROJECT_DIR
  cd "${PROJECT_DIR}"
  ensure_runtime_dirs
  require_supporting_scripts
  ghcr_login_if_needed

  if [[ -f "${TLS_BOOTSTRAPPED_MARKER}" ]]; then
    steady_state_deploy
  else
    fresh_host_deploy
  fi

  echo "Deployment completed: ${IMAGE_URI}"
}

main "$@"
