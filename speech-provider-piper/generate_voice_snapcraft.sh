#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate_voice_snapcraft.sh <language> <country> <name> <quality>

Example:
  generate_voice_snapcraft.sh en us amy medium

Notes:
  - language/country/name/quality should be simple tokens (letters/digits/_/-)
  - YAML file will be written to ./voices/piper-voices-<language>-<country>/snapcraft.yaml
EOF
}

validate_token() {
  local token="$1"
  local label="$2"
  if [[ ! "$token" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Invalid ${label}: ${token}" >&2
    exit 1
  fi
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage
  exit 1
fi

language_raw="$1"
country_raw="$2"
name_raw="$3"
quality_raw="$4"
output_path="${5:-}"

validate_token "$language_raw" "language"
validate_token "$country_raw" "country"
validate_token "$name_raw" "name"
validate_token "$quality_raw" "quality"

language_lower="$(printf '%s' "$language_raw" | tr '[:upper:]' '[:lower:]')"
country_lower="$(printf '%s' "$country_raw" | tr '[:upper:]' '[:lower:]')"
country_upper="$(printf '%s' "$country_raw" | tr '[:lower:]' '[:upper:]')"
name_lower="$(printf '%s' "$name_raw" | tr '[:upper:]' '[:lower:]')"
quality_lower="$(printf '%s' "$quality_raw" | tr '[:upper:]' '[:lower:]')"

locale_dash="${language_lower}-${country_upper}"
locale_underscore="${language_lower}_${country_upper}"
voice_id="${locale_dash}.${name_lower}-${quality_lower}"
pack_name="piper-voices-${language_lower}-${country_lower}"
part_name="voices-${language_lower}-${country_lower}-${name_lower}-${quality_lower}"
onnx_file="${locale_underscore}-${name_lower}-${quality_lower}.onnx"
base_url="https://huggingface.co/rhasspy/piper-voices/resolve/main/${language_lower}/${locale_underscore}/${name_lower}/${quality_lower}"


output_path=./voices/${pack_name}/snapcraft.yaml
mkdir -p "$(dirname "$output_path")"

cat <<EOF > "${output_path:-/dev/stdout}"
name: ${pack_name}
summary: Piper voices content snap (${locale_underscore})
description: |
  Content snap that provides the Piper ${locale_underscore} voice model files.
version: '0.1'
grade: devel
confinement: strict
base: core26

slots:
  piper-voices:
    interface: content
    content: piper-voices
    source:
      read:
        - /${voice_id}

parts:
  ${part_name}:
    plugin: nil
    build-packages:
      - curl
      - ca-certificates
    override-build: |
      set -eu
      mkdir -p "\$CRAFT_PART_INSTALL/${voice_id}"
      curl -L --fail --retry 3 \\
        -o "\$CRAFT_PART_INSTALL/${voice_id}/${onnx_file}" \\
        "${base_url}/${onnx_file}"
      curl -L --fail --retry 3 \\
        -o "\$CRAFT_PART_INSTALL/${voice_id}/${onnx_file}.json" \\
        "${base_url}/${onnx_file}.json"
EOF

echo "Wrote ${output_path}"
