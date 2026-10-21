#!/usr/bin/env bash
# Megamind Studios v1 - apply the patch onto a fresh Wan2GP clone.
# Run INSIDE the Wan2GP clone:  bash /path/to/apply_patch.sh
# Pins the verified upstream commit; refuses to apply onto anything else.
set -e
PINNED_COMMIT=fdc63bd
PINNED_SUBJECT="fixed audio continuity"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${1:-$SCRIPT_DIR/megamind-v1.patch}"
if [ ! -d .git ] || [ ! -f wgp.py ]; then
  echo "Run this inside a Wan2GP clone (git clone https://github.com/deepbeepmeep/Wan2GP)"; exit 1
fi
if [ ! -f "$PATCH_FILE" ]; then
  echo "Patch file not found: $PATCH_FILE"; echo "Pass its path as the first argument."; exit 1
fi
current=$(git rev-parse --short HEAD)
if [ "$current" != "$PINNED_COMMIT" ]; then
  echo "This patch is verified against Wan2GP commit $PINNED_COMMIT ('$PINNED_SUBJECT')."
  echo "Current HEAD is $current. Run: git checkout $PINNED_COMMIT  (or review the patch manually)."
  exit 1
fi
git apply --check "$PATCH_FILE" && git apply "$PATCH_FILE"
echo "Megamind patch applied cleanly onto $PINNED_COMMIT."
