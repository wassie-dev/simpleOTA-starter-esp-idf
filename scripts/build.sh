#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build"
EXAMPLE="${ROOT}/sdkconfig.secrets.example"
SECRETS="${ROOT}/sdkconfig.secrets"

supported_chip() {
  case "$1" in
    esp32|esp32s2|esp32s3|esp32c3|esp32c6|esp32h2) return 0 ;;
    *) return 1 ;;
  esac
}

CHIP="${SIMPLEOTA_CHIP:-esp32}"
if ! supported_chip "${CHIP}"; then
  echo "Unsupported SIMPLEOTA_CHIP '${CHIP}'. Supported chips: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2." >&2
  exit 1
fi

if [[ "${SIMPLEOTA_RELEASE:-}" == "true" ]]; then
  "${ROOT}/scripts/secrets.sh" check
elif [[ ! -f "${SECRETS}" ]]; then
  cp "${EXAMPLE}" "${SECRETS}"
fi

cd "${ROOT}"
idf.py set-target "${CHIP}"
idf.py build

mkdir -p "${BUILD}"
printf '%s\n' "${CHIP}" > "${BUILD}/chip"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "chip=${CHIP}" >> "${GITHUB_OUTPUT}"
fi
