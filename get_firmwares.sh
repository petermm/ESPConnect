#!/usr/bin/env bash
# Downloads the latest successful la_machine CI firmware artifacts and writes
# them into ESPConnect's public firmware bundle.
#
# Requirements: gh (GitHub CLI), jq, unzip
# Usage: ./get_firmwares.sh

set -euo pipefail

REPO="pguyot/la_machine"
WORKFLOW_FILE="build.yaml"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="${ROOT_DIR}/public/assets/firmware"
DEST_RETAIL="${DEST_DIR}/la_machine.bin"
DEST_PROTO="${DEST_DIR}/la_machine_proto.bin"
DEST_4MB="${DEST_DIR}/la_machine_4mb.bin"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

for cmd in gh jq unzip; do
  command -v "$cmd" >/dev/null || { echo "Error: $cmd is required but not found." >&2; exit 1; }
done

mkdir -p "$DEST_DIR"

echo "Fetching latest successful workflow run for ${REPO}..."
RUN_ID=$(gh api "repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?status=success&branch=main&per_page=1" \
  --jq '.workflow_runs[0].id')

if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
  echo "Error: No successful workflow run found." >&2
  exit 1
fi

echo "Using run ID: ${RUN_ID}"

echo "Listing artifacts..."
ARTIFACTS_JSON=$(gh api "repos/${REPO}/actions/runs/${RUN_ID}/artifacts" --paginate \
  --jq '[.artifacts[] | {name, id}]')

ARTIFACT_COUNT=$(echo "$ARTIFACTS_JSON" | jq 'length')
echo "Found ${ARTIFACT_COUNT} artifact(s)."

ARTIFACT_LINES=$(echo "$ARTIFACTS_JSON" | jq -r '.[] | [.name, (.id|tostring)] | @tsv')

file_size() {
  if stat -f%z "$1" >/dev/null 2>&1; then
    stat -f%z "$1"
  else
    stat -c%s "$1"
  fi
}

pick_artifact() {
  local variant="$1"
  local name id lower

  while IFS=$'\t' read -r name id; do
    lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lower" != *la_machine* ]]; then
      continue
    fi

    if [[ "$lower" == *sound* ]]; then
      continue
    fi

    if [[ "$lower" != *".img" ]]; then
      continue
    fi

    case "$variant" in
      proto)
        if [[ "$lower" == *proto* ]]; then
          printf '%s\t%s\n' "$name" "$id"
          return 0
        fi
        ;;
      4mb)
        if [[ "$lower" == *4mb* || "$lower" == *4-mb* || "$lower" == *4_mb* ]]; then
          printf '%s\t%s\n' "$name" "$id"
          return 0
        fi
        ;;
      retail)
        if [[ "$lower" != *proto* && "$lower" != *4mb* && "$lower" != *4-mb* && "$lower" != *4_mb* ]]; then
          printf '%s\t%s\n' "$name" "$id"
          return 0
        fi
        ;;
      *)
        echo "Error: unknown variant '${variant}'" >&2
        return 2
        ;;
    esac
  done <<< "$ARTIFACT_LINES"

  echo "Error: could not find artifact for variant '${variant}' in run ${RUN_ID}" >&2
  return 1
}

download_and_extract() {
  local name="$1"
  local id="$2"
  local dest="$3"

  mkdir -p "$dest"
  echo "  Downloading ${name}..."
  gh api "repos/${REPO}/actions/artifacts/${id}/zip" > "${TMP_DIR}/${name}.zip"
  unzip -o "${TMP_DIR}/${name}.zip" -d "$dest" >/dev/null
  rm "${TMP_DIR}/${name}.zip"
}

find_firmware_file() {
  local dir="$1"
  local best_file=""
  local best_size=0
  local candidate size

  while IFS= read -r -d '' candidate; do
    size="$(file_size "$candidate")"
    if [[ -z "$best_file" || "$size" -gt "$best_size" ]]; then
      best_file="$candidate"
      best_size="$size"
    fi
  done < <(find "$dir" -type f \( -name '*.img' -o -name '*.bin' \) ! -name 'sounds.bin' -print0)

  if [[ -z "$best_file" ]]; then
    echo ""
    return 1
  fi

  printf '%s\n' "$best_file"
}

write_firmware() {
  local variant="$1"
  local dest_file="$2"
  local name id extract_dir firmware_file

  IFS=$'\t' read -r name id < <(pick_artifact "$variant")
  extract_dir="${TMP_DIR}/${variant}"
  download_and_extract "$name" "$id" "$extract_dir"

  firmware_file="$(find_firmware_file "$extract_dir")"
  if [[ -z "$firmware_file" ]]; then
    echo "Error: no firmware file found inside artifact '${name}'" >&2
    return 1
  fi

  cp "$firmware_file" "$dest_file"
  echo "  Wrote ${dest_file} ($(basename "$firmware_file"))"
}

echo "Downloading and writing firmware binaries..."
write_firmware "retail" "$DEST_RETAIL"
write_firmware "proto" "$DEST_PROTO"
write_firmware "4mb" "$DEST_4MB"

echo "Done."
