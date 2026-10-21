#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="${ROOT}/sdkconfig.secrets.example"
DEST="${ROOT}/sdkconfig.secrets"

value_is_placeholder() {
  local value=$1
  local placeholder
  while IFS= read -r placeholder; do
    if [[ -n "${placeholder}" && "${value}" == "${placeholder}" ]]; then
      return 0
    fi
  done < <(sed -n 's/^CONFIG_[^=]*="\(.*\)"$/\1/p' "${EXAMPLE}")
  return 1
}

allowed_secret_option() {
  case "$1" in
    CONFIG_EXAMPLE_WIFI_SSID|CONFIG_EXAMPLE_WIFI_PASSWORD|CONFIG_EXAMPLE_SIMPLEOTA_TOKEN)
      return 0
      ;;
  esac
  return 1
}

validate_secrets_file() {
  local file=$1
  local line key rest value
  local has_ssid=0 has_pass=0 has_token=0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*$ || "${line}" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ ! "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
      echo "sdkconfig.secrets contains a line other than the Wi-Fi SSID, Wi-Fi password, and device token options." >&2
      exit 1
    fi
    key="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    if ! allowed_secret_option "${key}"; then
      echo "sdkconfig.secrets must not set ${key}." >&2
      exit 1
    fi
    if [[ "${rest}" != \"*\" ]]; then
      echo "sdkconfig.secrets has a malformed ${key} line." >&2
      exit 1
    fi
    value="${rest:1:${#rest}-2}"
    if value_is_placeholder "${value}"; then
      echo "sdkconfig.secrets uses a placeholder value." >&2
      exit 1
    fi
    case "${key}" in
      CONFIG_EXAMPLE_WIFI_SSID) has_ssid=1 ;;
      CONFIG_EXAMPLE_WIFI_PASSWORD) has_pass=1 ;;
      CONFIG_EXAMPLE_SIMPLEOTA_TOKEN) has_token=1 ;;
    esac
  done < "${file}"

  if [[ "${has_ssid}" -eq 0 || "${has_pass}" -eq 0 || "${has_token}" -eq 0 ]]; then
    echo "sdkconfig.secrets does not set the Wi-Fi and device token options." >&2
    exit 1
  fi
}

check_secrets() {
  if [[ ! -f "${DEST}" ]]; then
    echo "Release build is missing sdkconfig.secrets." >&2
    exit 1
  fi
  validate_secrets_file "${DEST}"
}

kconfig_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "${value}"
}

require_secret() {
  local name=$1
  local value=${!name-}
  if [[ -z "${value}" ]]; then
    echo "Missing secret ${name}." >&2
    return 1
  fi
  if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
    echo "Secret ${name} contains a newline." >&2
    return 1
  fi
  if value_is_placeholder "${value}"; then
    echo "Secret ${name} is still a placeholder." >&2
    return 1
  fi
}

write_secrets() {
  local missing=0
  local tmp
  require_secret SIMPLEOTA_WIFI_SSID || missing=1
  require_secret SIMPLEOTA_WIFI_PASSWORD || missing=1
  require_secret SIMPLEOTA_DEVICE_TOKEN || missing=1
  if [[ "${missing}" -ne 0 ]]; then
    exit 1
  fi

  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' EXIT
  {
    printf 'CONFIG_EXAMPLE_WIFI_SSID="%s"\n' "$(kconfig_escape "${SIMPLEOTA_WIFI_SSID}")"
    printf 'CONFIG_EXAMPLE_WIFI_PASSWORD="%s"\n' "$(kconfig_escape "${SIMPLEOTA_WIFI_PASSWORD}")"
    printf 'CONFIG_EXAMPLE_SIMPLEOTA_TOKEN="%s"\n' "$(kconfig_escape "${SIMPLEOTA_DEVICE_TOKEN}")"
  } > "${tmp}"
  validate_secrets_file "${tmp}"
  mv "${tmp}" "${DEST}"
  trap - EXIT
}

case "${1:-}" in
  write) write_secrets ;;
  check) check_secrets ;;
  *)
    echo "Usage: secrets.sh write|check" >&2
    exit 1
    ;;
esac
