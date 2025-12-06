#!/usr/bin/env bash
set -euo pipefail
DEST_DIR="${1:-docs}"
mkdir -p "$DEST_DIR"
curl -L --retry 3 --fail -o "$DEST_DIR/MCRP_1-10.1.pdf" "https://www.marines.mil/Portals/1/Publications/MCRP%201-10.1.pdf"
curl -L --retry 3 --fail -o "$DEST_DIR/MCWP_5-10.pdf" "https://www.marines.mil/Portals/1/Publications/MCWP%205-10.pdf"
