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
  - voices (as name-quality entries) and test_phrase are read from voices.yaml
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

locale_raw="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
voices_yaml="${script_dir}/voices.yaml"

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

test_phrase="$(yq -r --arg locale "$locale_dash" '.[$locale].test_phrase' "$voices_yaml")"

mapfile -t voice_ids < <(yq -r --arg locale "$locale_dash" '.[$locale].voices[]' "$voices_yaml")

if [[ "${#voice_ids[@]}" -eq 0 ]]; then
  echo "No voices configured for locale ${locale_dash} in ${voices_yaml}" >&2
  exit 1
fi

voice_names=()
voice_qualities=()
for voice_id in "${voice_ids[@]}"; do
  voice_names+=("${voice_id%-*}")
  voice_qualities+=("${voice_id##*-}")
done

pack_name="piper-voices-${language_lower}-${country_lower}"
base_url_prefix="https://huggingface.co/rhasspy/piper-voices/resolve/main/${language_lower}/${locale_underscore}"

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
EOF

for i in "${!voice_names[@]}"; do
  name_lower="$(printf '%s' "${voice_names[$i]}" | tr '[:upper:]' '[:lower:]')"
  quality_lower="$(printf '%s' "${voice_qualities[$i]}" | tr '[:upper:]' '[:lower:]')"
  voice_id="${locale_dash}.${name_lower}-${quality_lower}"
  printf '        - /%s\n' "${voice_id}"
done

cat <<EOF

parts:
  test-phrase:
    plugin: nil
    override-build: |
      set -eu
      printf '%s\n' "${test_phrase}" > "\$CRAFT_PART_INSTALL/test_phrase.txt"
EOF

for i in "${!voice_names[@]}"; do
  name_lower="$(printf '%s' "${voice_names[$i]}" | tr '[:upper:]' '[:lower:]')"
  quality_lower="$(printf '%s' "${voice_qualities[$i]}" | tr '[:upper:]' '[:lower:]')"
  voice_id="${locale_dash}.${name_lower}-${quality_lower}"
  part_name="voices-${language_lower}-${country_lower}-${name_lower}-${quality_lower}"
  onnx_file="${locale_underscore}-${name_lower}-${quality_lower}.onnx"
  base_url="${base_url_prefix}/${name_lower}/${quality_lower}"

  cat <<EOF
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
done
