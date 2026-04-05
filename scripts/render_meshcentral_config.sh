#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEMPLATE_PATH="${PROJECT_DIR}/config/config.template.json"
OUTPUT_PATH="${PROJECT_DIR}/data/config.json"

MESH_FQDN="${MESH_FQDN:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
TRUSTED_PROXY="${TRUSTED_PROXY:-nginx,127.0.0.1,::1}"
CERT_URL="${CERT_URL:-https://nginx:443/}"

if [[ -z "${MESH_FQDN}" ]]; then
  echo "MESH_FQDN is required" >&2
  exit 1
fi

if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
  echo "LETSENCRYPT_EMAIL is required" >&2
  exit 1
fi

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Missing config template: ${TEMPLATE_PATH}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"

mesh_fqdn_escaped="$(printf '%s' "${MESH_FQDN}" | sed 's/[\\/&]/\\&/g')"
letsencrypt_email_escaped="$(printf '%s' "${LETSENCRYPT_EMAIL}" | sed 's/[\\/&]/\\&/g')"
trusted_proxy_escaped="$(printf '%s' "${TRUSTED_PROXY}" | sed 's/[\\/&]/\\&/g')"
cert_url_escaped="$(printf '%s' "${CERT_URL}" | sed 's/[\\/&]/\\&/g')"

sed \
  -e "s|\${MESH_FQDN}|${mesh_fqdn_escaped}|g" \
  -e "s|\${LETSENCRYPT_EMAIL}|${letsencrypt_email_escaped}|g" \
  -e "s|\${TRUSTED_PROXY}|${trusted_proxy_escaped}|g" \
  -e "s|\${CERT_URL}|${cert_url_escaped}|g" \
  "${TEMPLATE_PATH}" > "${OUTPUT_PATH}"

if grep -q '\${[A-Z0-9_]\+}' "${OUTPUT_PATH}"; then
  echo "Config render left unresolved placeholders in ${OUTPUT_PATH}" >&2
  exit 1
fi

echo "Rendered MeshCentral config: ${OUTPUT_PATH}"
