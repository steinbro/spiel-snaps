#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate_voice_snapcraft.sh <locale>

Example:
  generate_voice_snapcraft.sh en-US

Notes:
  - locale must look like ll-CC
  - voice, quality, and test_phrase are read from voices.json
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

locale_raw="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
voices_json="${script_dir}/voices.json"

if [[ ! "$locale_raw" =~ ^([A-Za-z0-9_]+)-([A-Za-z0-9_]+)$ ]]; then
	usage
	exit 1
fi

language_raw="${BASH_REMATCH[1]}"
country_raw="${BASH_REMATCH[2]}"

language_lower="$(printf '%s' "$language_raw" | tr '[:upper:]' '[:lower:]')"
country_lower="$(printf '%s' "$country_raw" | tr '[:upper:]' '[:lower:]')"
country_upper="$(printf '%s' "$country_raw" | tr '[:lower:]' '[:upper:]')"

locale_dash="${language_lower}-${country_upper}"
locale_underscore="${language_lower}_${country_upper}"

name_raw="$(jq -r --arg locale "$locale_dash" '.[$locale].name' "$voices_json")"
quality_raw="$(jq -r --arg locale "$locale_dash" '.[$locale].quality' "$voices_json")"
test_phrase="$(jq -r --arg locale "$locale_dash" '.[$locale].test_phrase' "$voices_json")"

name_lower="$(printf '%s' "$name_raw" | tr '[:upper:]' '[:lower:]')"
quality_lower="$(printf '%s' "$quality_raw" | tr '[:upper:]' '[:lower:]')"

voice_id="${locale_dash}.${name_lower}-${quality_lower}"
pack_name="piper-voices-${language_lower}-${country_lower}"
part_name="voices-${language_lower}-${country_lower}-${name_lower}-${quality_lower}"
onnx_file="${locale_underscore}-${name_lower}-${quality_lower}.onnx"
base_url="https://huggingface.co/rhasspy/piper-voices/resolve/main/${language_lower}/${locale_underscore}/${name_lower}/${quality_lower}"

cat <<EOF
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
      printf '%s\n' "${test_phrase}" > "\$CRAFT_PART_INSTALL/test_phrase.txt"
      curl -L --fail --retry 3 \\
        -o "\$CRAFT_PART_INSTALL/${voice_id}/${onnx_file}.json" \\
        "${base_url}/${onnx_file}.json"
EOF
