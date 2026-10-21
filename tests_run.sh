#!/usr/bin/env bash
# Megamind Studios v1 - automated checks. No GPU needed.
# Portable: run from anywhere. Needs git, python3, and a Wan2GP clone.
#
#   ./tests_run.sh [WAN2GP_CLONE_DIR] [PATCH_FILE]
#
# Defaults: clone = ./Wan2GP (or $WAN2GP_DIR), patch = megamind-v1.patch next
# to this script. apply_patch.sh is taken from next to this script.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:-${WAN2GP_DIR:-$PWD/Wan2GP}}"
PATCH="${2:-$SCRIPT_DIR/megamind-v1.patch}"
APPLY_SH="$SCRIPT_DIR/apply_patch.sh"
PINNED=fdc63bd
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
PY="${PYTHON:-python3}"
command -v git >/dev/null || { echo "git required"; exit 1; }
command -v "$PY" >/dev/null || { echo "python3 required (set PYTHON=...)"; exit 1; }
[ -d "$SRC/.git" ] || { echo "Wan2GP clone not found at $SRC - pass its path as argument 1"; exit 1; }
[ -f "$PATCH" ] || { echo "patch not found at $PATCH"; exit 1; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

fresh() { rm -rf "$1"; git clone -q "$SRC" "$1" 2>/dev/null; }

# 1. Patch applies cleanly onto the pinned upstream commit
fresh "$WORK/t1" && cd "$WORK/t1" && git checkout -q -f $PINNED
if git apply --check "$PATCH" 2>/dev/null && git apply "$PATCH" 2>/dev/null; then ok "patch applies cleanly onto pinned commit $PINNED"; else bad "patch does not apply onto $PINNED"; fi

# 2. apply_patch.sh REFUSES a wrong base commit (real guard check: exit code + message)
WRONG=$(git -C "$SRC" rev-parse --short HEAD)
if [ "$WRONG" = "$PINNED" ]; then WRONG=$(git -C "$SRC" rev-parse --short "$PINNED~1" 2>/dev/null || true); fi
if [ -z "$WRONG" ] || [ "$WRONG" = "$PINNED" ]; then bad "no non-pinned commit available for guard test"; else
fresh "$WORK/t2" && cd "$WORK/t2" && git checkout -q -f "$WRONG"
OUT=$(bash "$APPLY_SH" "$PATCH" 2>&1); RC=$?
if [ $RC -ne 0 ] && echo "$OUT" | grep -q "$PINNED"; then ok "apply_patch.sh refuses non-pinned commit $WRONG (exit $RC, names $PINNED)"; else bad "apply_patch.sh guard broken (exit $RC): $OUT"; fi
fi

# 3. apply_patch.sh APPLIES onto the pinned commit (real helper path)
fresh "$WORK/t3" && cd "$WORK/t3" && git checkout -q -f $PINNED
if bash "$APPLY_SH" "$PATCH" >/dev/null 2>&1 && grep -q "Megamind Studios" wgp.py; then ok "apply_patch.sh applies onto $PINNED"; else bad "apply_patch.sh failed onto $PINNED"; fi

# 4. Curation on the patched tree: 268 hidden, exactly 4 visible
cd "$WORK/t1" && rm -rf finetunes && mkdir -p finetunes && "$PY" megamind/curate_models.py >/dev/null
missing=0; visible=0
for f in defaults/*.json; do
  mt=$(basename "$f" .json); stub="finetunes/$mt.json"
  case "$mt" in ti2v_2_2|qwen_image_20B|chatterbox|ace_step_v1_5)
    [ -f "$stub" ] && bad "allowlisted $mt got a hiding stub" || visible=$((visible+1));;
  *) { [ -f "$stub" ] && grep -q '"visible": false' "$stub"; } || { missing=$((missing+1)); bad "stub missing: $mt"; };;
  esac
done
[ "$missing" = 0 ] && [ "$visible" = 4 ] && ok "curation: all non-curated hidden, exactly 4 visible" || bad "curation wrong: $missing missing stubs, $visible visible"

# 5. Config template: valid JSON, allowlist, megamind theme, ti2v_2_2 default
"$PY" - "$WORK/t1" <<'PYEOF' && ok "wgp_config.template.json valid" || bad "config template invalid"
import json,sys
c=json.load(open(sys.argv[1]+"/megamind/wgp_config.template.json"))
assert c.get("transformer_types")==["ti2v_2_2","qwen_image_20B","chatterbox","ace_step_v1_5"]
assert c.get("UI_theme")=="megamind" and c.get("last_model_type")=="ti2v_2_2"
PYEOF

# 6. Megamind theme builds; per-theme CSS wired (full build when gradio is installed, static wiring check otherwise)
cd "$WORK/t1"
if "$PY" -c "import gradio" 2>/dev/null; then
  "$PY" - <<'PYEOF' && ok "megamind theme builds and CSS override file is wired" || bad "theme build failed"
import sys; sys.path.insert(0,".")
from shared.gradio import ui_studio
t=ui_studio.create_theme("megamind"); assert t is not None
import os; assert os.path.exists("shared/gradio/ui_studio_megamind.css")
PYEOF
else
  grep -q "'megamind'" shared/gradio/ui_studio.py && [ -f shared/gradio/ui_studio_megamind.css ] \
    && ok "megamind theme wired (static check; install gradio for full build test)" || bad "megamind theme wiring missing"
fi

# 7. neutral_hue override is scoped to megamind; other themes keep slate
grep -q "neutral_hue='stone' if name == 'megamind' else 'slate'" "$WORK/t1/shared/gradio/ui_studio.py" \
  && ok "neutral_hue scoped to megamind (other themes keep slate)" || bad "neutral_hue change leaks into other themes"

# 8. setup.bat: Git + Python checks, pinned checkout, pinned torch stack, no launcher overwrite
SB="$SCRIPT_DIR/setup_megamind_windows.bat"
g() { grep -q "$1" "$SB"; }
g "where git" && g "py -3.10" && g "checkout %PINNED%" \
  && g "torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1" \
  && g "findstr /V /I /C:" \
  && g 'requirements_megamind.txt' \
  && ok "setup.bat: git/python checks, pinned checkout, pinned torch stack, torchcodec excluded (documented)" || bad "setup.bat missing required logic"
if grep -q "torchcodec==0.5.0" "$SB"; then bad "setup.bat pins torchcodec 0.5.0 (no Windows wheel exists)"; else ok "setup.bat has no unshippable torchcodec pin"; fi
g "pip install --upgrade pip" && g 'typing-extensions>=4.10' \
  && ok "setup.bat pre-installs typing-extensions from PyPI (cu128 index sdist trap, found by CI run 2)" || bad "setup.bat missing typing-extensions pre-install"
if grep -q "^echo @echo off>" "$SB"; then bad "setup.bat overwrites the guarded launcher"; else ok "setup.bat preserves the guarded launcher"; fi

# 9. Final installed launcher is the guarded one from the patch
grep -q "Setup not done yet" "$WORK/t1/run_megamind_windows.bat" \
  && ok "installed run_megamind_windows.bat carries the setup guard" || bad "installed launcher missing setup guard"

# 10. License and notices
cmp -s "$WORK/t1/LICENSE.txt" "$SRC/LICENSE.txt" 2>/dev/null || diff <(git -C "$SRC" show $PINNED:LICENSE.txt) "$WORK/t1/LICENSE.txt" >/dev/null \
  && ok "LICENSE.txt intact" || bad "LICENSE.txt changed"
grep -q 'title="Megamind Studios"' "$WORK/t1/wgp.py" && ! grep -qi "powered by" "$WORK/t1/wgp.py" \
  && ok "header is Megamind-only, no powered-by" || bad "header check failed"
grep -q "WanGP Copyright DeepBeepMeep" "$WORK/t1/wgp.py" && grep -q "by DeepBeepMeep" "$WORK/t1/wgp.py" \
  && ok "upstream credits preserved in wgp.py" || bad "upstream credits missing"
grep -Eq "20[0-9]{2}-[0-9]{2}-[0-9]{2}" "$WORK/t1/megamind/MEGAMIND.md" \
  && ok "modification notice dated (license 4.1d)" || bad "modification notice missing date"

# 11. Delivered .bat files are line-ending safe (no multi-line blocks, no labels) - valid under LF or CRLF
lfsafe() { ! grep -qE '^[[:space:]]*\)' "$1" && ! grep -qE '^[[:space:]]*goto |^[[:space:]]*:[A-Za-z]' "$1"; }
lfsafe "$SB" && ok "setup.bat is line-ending safe (no blocks/labels)" || bad "setup.bat has LF-fragile constructs"
"$PY" - "$PATCH" <<'PYEOF' && ok "patch-carried launcher is line-ending safe" || bad "patch launcher has LF-fragile constructs"
import sys
txt=open(sys.argv[1],encoding='utf-8').read()
import re
sec=txt.split('run_megamind_windows.bat')[1]
assert 'goto' not in sec.lower()
for line in sec.splitlines():
    body=line[1:] if line[:1] in '+- ' else line
    assert not body.strip().startswith(')'), body
PYEOF
grep -q "fdc63bdf89358fb13c93cf6b38693fd89a859f00" "$APPLY_SH" \
  && ok "apply_patch.sh pins the full 40-char commit SHA" || bad "apply_patch.sh uses short SHA"

echo "== $PASS passed, $FAIL failed =="
[ $FAIL = 0 ]
