#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NGINX_DIR="${PROJECT_DIR}/nginx"

MESH_FQDN="${MESH_FQDN:-}"
if [[ -z "${MESH_FQDN}" ]]; then
  echo "MESH_FQDN is required" >&2
  exit 1
fi

CERTBOT_WEBROOT="${CERTBOT_WEBROOT:-/var/www/certbot}"
TLS_CERT_FULLCHAIN="${TLS_CERT_FULLCHAIN:-/etc/letsencrypt/live/${MESH_FQDN}/fullchain.pem}"
TLS_CERT_PRIVKEY="${TLS_CERT_PRIVKEY:-/etc/letsencrypt/live/${MESH_FQDN}/privkey.pem}"

case "${MODE}" in
  bootstrap)
    TEMPLATE_PATH="${NGINX_DIR}/meshcentral.http-bootstrap.conf.template"
    ;;
  https)
    TEMPLATE_PATH="${NGINX_DIR}/meshcentral.https.conf.template"
    ;;
  *)
    echo "Unsupported mode: ${MODE}. Use bootstrap or https." >&2
    exit 1
    ;;
esac

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Missing Nginx template: ${TEMPLATE_PATH}" >&2
  exit 1
fi

mesh_fqdn_escaped="$(printf '%s' "${MESH_FQDN}" | sed 's/[\\/&]/\\&/g')"
certbot_webroot_escaped="$(printf '%s' "${CERTBOT_WEBROOT}" | sed 's/[\\/&]/\\&/g')"
tls_cert_fullchain_escaped="$(printf '%s' "${TLS_CERT_FULLCHAIN}" | sed 's/[\\/&]/\\&/g')"
tls_cert_privkey_escaped="$(printf '%s' "${TLS_CERT_PRIVKEY}" | sed 's/[\\/&]/\\&/g')"

sed \
  -e "s|\${MESH_FQDN}|${mesh_fqdn_escaped}|g" \
  -e "s|\${CERTBOT_WEBROOT}|${certbot_webroot_escaped}|g" \
  -e "s|\${TLS_CERT_FULLCHAIN}|${tls_cert_fullchain_escaped}|g" \
  -e "s|\${TLS_CERT_PRIVKEY}|${tls_cert_privkey_escaped}|g" \
  "${TEMPLATE_PATH}" > "${NGINX_DIR}/meshcentral.conf"

echo "Rendered Nginx config in ${MODE} mode: ${NGINX_DIR}/meshcentral.conf"
