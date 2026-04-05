#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MESH_FQDN="${MESH_FQDN:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
CERTBOT_WEBROOT_HOST="${CERTBOT_WEBROOT_HOST:-${PROJECT_DIR}/.certbot/www}"
LETSENCRYPT_DIR_HOST="${LETSENCRYPT_DIR_HOST:-${PROJECT_DIR}/.certbot/conf}"
LETSENCRYPT_LIB_HOST="${LETSENCRYPT_LIB_HOST:-${PROJECT_DIR}/.certbot/lib}"
CERTBOT_WEBROOT="${CERTBOT_WEBROOT:-/var/www/certbot}"
LETSENCRYPT_DIR="${LETSENCRYPT_DIR:-/etc/letsencrypt}"

if [[ -z "${MESH_FQDN}" ]]; then
  echo "MESH_FQDN is required" >&2
  exit 1
fi

if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
  echo "LETSENCRYPT_EMAIL is required" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on the host" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is required on the host" >&2
  exit 1
fi

if ! grep -q ':443' "${PROJECT_DIR}/docker-compose.yml"; then
  echo "docker-compose.yml is not wired for HTTPS yet!" >&2
  exit 1
fi

mkdir -p "${CERTBOT_WEBROOT_HOST}" "${LETSENCRYPT_DIR_HOST}" "${LETSENCRYPT_LIB_HOST}"

bash "${PROJECT_DIR}/scripts/render_nginx_config.sh" bootstrap

echo "Bootstrap HTTP-only Nginx config rendered."
echo "deploy.sh now owns the main first-boot orchestration."
echo "Use this helper only for manual troubleshooting or guided recovery."
echo
echo "Example manual Certbot command:"
echo "docker run --rm \\"
echo "  -v ${LETSENCRYPT_DIR_HOST}:${LETSENCRYPT_DIR} \\"
echo "  -v ${LETSENCRYPT_LIB_HOST}:/var/lib/letsencrypt \\"
echo "  -v ${CERTBOT_WEBROOT_HOST}:${CERTBOT_WEBROOT} \\"
echo "  certbot/certbot certonly --webroot -w /var/www/certbot \\"
echo "  --email ${LETSENCRYPT_EMAIL} --agree-tos --no-eff-email --non-interactive \\"
echo "  -d ${MESH_FQDN}"
