#!/usr/bin/env bash

set -euo pipefail

DOCKERFILE_PATH="${1:-docker/Dockerfile}"
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ylianst/meshcentral}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-${BASE_IMAGE}:latest}"



write_output() {
  local key="$1"
  local value="$2"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  fi
}

escaped_base_image="$(
  printf '%s' "$BASE_IMAGE" | sed 's/[][(){}.^$*+?|/]/\\&/g'
)"

# Pin the current digest from the FROM line
current_from_line="$(
  awk -v prefix="FROM ${BASE_IMAGE}@" '
    index($0, prefix) == 1 {
      print
      exit
    }
  ' "$DOCKERFILE_PATH"
)"
# Add some debugger to help with future debug
echo "DOCKERFILE_PATH=${DOCKERFILE_PATH}" >&2
echo "BASE_IMAGE=${BASE_IMAGE}" >&2
echo "BASE_IMAGE_TAG=${BASE_IMAGE_TAG}" >&2
echo "Looking for current FROM prefix: FROM ${BASE_IMAGE}@" >&2
echo "Dockerfile FROM lines:" >&2
grep -n '^FROM ' "$DOCKERFILE_PATH" >&2 || true

if [[ -z "$current_from_line" ]]; then
  echo "Could not find a pinned MeshCentral FROM line in ${DOCKERFILE_PATH}" >&2
  exit 1
fi

if ! printf '%s\n' "$current_from_line" | grep -Eq "^FROM ${escaped_base_image}@sha256:[0-9a-f]{64}$"; then
  echo "MeshCentral FROM line is not pinned to a sha256 digest: ${current_from_line}" >&2
  exit 1
fi

current_digest="${current_from_line##*@}"

# Find the latest digest for the base image from the registry
inspect_output="$(docker buildx imagetools inspect "$BASE_IMAGE_TAG")"

# Add some debugger to help with future debug
echo "Inspecting upstream ref: ${BASE_IMAGE_TAG}" >&2
echo "Resolved inspect output:" >&2
printf '%s\n' "$inspect_output" >&2

latest_digest="$(
  printf '%s\n' "$inspect_output" | awk '
    $1 == "Digest:" {
      print $2
      exit
    }
  '
)"

if ! printf '%s\n' "$latest_digest" | grep -Eq '^sha256:[0-9a-f]{64}$'; then
  echo "Unable to determine the upstream digest for ${BASE_IMAGE_TAG}" >&2
  exit 1
fi

# Add some debugger to help with future debug
echo "Current digest: ${current_digest}" >&2
echo "Latest digest: ${latest_digest}" >&2

write_output "current_digest" "$current_digest"
write_output "latest_digest" "$latest_digest"

if [[ "$current_digest" == "$latest_digest" ]]; then
  echo "MeshCentral base image is already current at ${current_digest}"
  write_output "changed" "false"
  exit 0
fi

expected_from_line="FROM ${BASE_IMAGE}@${current_digest}"
updated_from_line="FROM ${BASE_IMAGE}@${latest_digest}"
tmpfile="$(mktemp)"

# Update the FROM line in the Dockerfile.
awk -v expected="$expected_from_line" -v replacement="$updated_from_line" '
  BEGIN {
    updated = 0
  }

  {
    if (!updated && $0 == expected) {
      print replacement
      updated = 1
      next
    }

    print
  }

  END {
    if (!updated) {
      exit 1
    }
  }
' "$DOCKERFILE_PATH" > "$tmpfile"

mv "$tmpfile" "$DOCKERFILE_PATH"

echo "Updated MeshCentral base image digest from ${current_digest} to ${latest_digest}"
write_output "changed" "true"
