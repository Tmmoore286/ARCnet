#!/usr/bin/env bash
set -euo pipefail

# Downloads all refs from known ARCnet manifests into Ref-Packs/all_refs
OUT_DIR="${1:-all_refs}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$BASE_DIR/$OUT_DIR"
mkdir -p "$DEST"

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
REF="https://www.marines.mil/"

fetch() {
  local url="$1"
  local name="$2"
  local out="$DEST/$name"
  echo "→ $name"
  if curl -L --retry 2 --fail -A "$UA" -H "Referer: $REF" -o "$out" "$url"; then
    echo "   ok ($out)"
  else
    echo "   FAILED ($url)" >&2
    return 1
  fi
}

download_csv() {
  local csv="$1"
  [ -f "$csv" ] || { echo "Missing manifest: $csv" >&2; return 0; }
  echo "Reading manifest: $csv"
  # Skip header; columns: Publication,Year,Type,Focus,URL
  tail -n +2 "$csv" | while IFS=',' read -r pub year type focus url; do
    # Build a safe filename from Publication
    safe=$(echo "$pub" | tr ' /:\t' '_')
    # Guess extension from URL
    ext="${url##*.}"; case "$ext" in pdf|html) ;; * ) ext="html" ;; esac
    fetch "$url" "${safe}.${ext}" || true
  done
}

download_csv "$BASE_DIR/../arcnet_doc_manifest.csv"
download_csv "$BASE_DIR/Project_ARCnet_Ref_Pack_2/arcnet_doctrine_modernization_manifest.csv"
download_csv "$BASE_DIR/Project_ARCnet_Support_Pack/arcnet_engineer_aviation_support_manifest.csv"

echo "Done. Files saved under $DEST"

