#!/usr/bin/env bash
# Megamind Studios v1 - automated checks. No GPU, no network beyond local git.
set -u
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
PY=/tmp/wangp-venv/bin/python
PATCH=/skills/personal/megamind-studios/megamind-v1.patch

fresh_clone() { rm -rf "$1"; git clone -q /tmp/wangp "$1" 2>/dev/null; }

# 1. Patch applies cleanly onto the pinned upstream commit
fresh_clone /tmp/t1 && cd /tmp/t1 && git checkout -q -f fdc63bd
if git apply --check "$PATCH" 2>/dev/null && git apply "$PATCH"; then ok "patch applies cleanly onto pinned commit fdc63bd"; else bad "patch does not apply onto fdc63bd"; fi

# 2. apply_patch.sh refuses a wrong base commit (fresh clone HEAD = megamind commit, not pinned)
fresh_clone /tmp/t2 && cd /tmp/t2 && cp "$PATCH" megamind/megamind-v1.patch
if bash megamind/apply_patch.sh >/dev/null 2>&1; then bad "apply_patch.sh applied onto wrong commit"; else ok "apply_patch.sh refuses non-pinned commit"; fi

# 3. Curation on the patched tree
cd /tmp/t1 && rm -rf finetunes && mkdir -p finetunes && $PY megamind/curate_models.py >/dev/null
missing=0; visible=0
for f in defaults/*.json; do
  mt=$(basename "$f" .json); stub="finetunes/$mt.json"
  case "$mt" in ti2v_2_2|qwen_image_20B|chatterbox|ace_step_v1_5)
    [ -f "$stub" ] && { bad "allowlisted $mt got a hiding stub"; } || visible=$((visible+1));;
  *) { [ -f "$stub" ] && grep -q '"visible": false' "$stub"; } || { missing=$((missing+1)); bad "stub missing: $mt"; };;
  esac
done
[ "$missing" = 0 ] && [ "$visible" = 4 ] && ok "curation: 268 hidden, exactly 4 visible" || bad "curation wrong: $missing missing stubs, $visible visible"

# 4. Config template parses and carries allowlist + theme + default model
$PY - <<'PYEOF' && ok "wgp_config.template.json valid: allowlist, megamind theme, ti2v_2_2 default" || bad "config template invalid"
import json
c=json.load(open('/tmp/t1/megamind/wgp_config.template.json'))
assert c['transformer_types']==["ti2v_2_2","qwen_image_20B","chatterbox","ace_step_v1_5"], c['transformer_types']
assert c['UI_theme']=='megamind' and c['last_model_type']=='ti2v_2_2'
PYEOF

# 5. Theme builds; per-theme CSS wired
cd /tmp/t1 && $PY - <<'PYEOF' && ok "megamind theme builds and CSS override file is wired" || bad "theme build failed"
from shared.gradio import ui_studio
t = ui_studio.create_theme('megamind')
assert t is not None and t.name == 'megamind'
assert any(v=='megamind' for _,v in ui_studio.THEME_CHOICES)
import pathlib
css = pathlib.Path('shared/gradio/ui_studio_megamind.css').read_text()
assert '#F06414' in css and 'chat__toggle-text' in css
src = pathlib.Path('shared/gradio/ui_studio.py').read_text()
assert "'megamind'" in src and "ui_studio_{theme.name}.css" in src
PYEOF

# 6. Setup/launch scripts failure handling
grep -q 'exit /b 1' /tmp/t1/setup_megamind_windows.bat && grep -q 'python.org' /tmp/t1/setup_megamind_windows.bat && ok "setup.bat checks Python 3.10 and fails with guidance" || bad "setup.bat missing python check"
grep -q 'setup_megamind_windows.bat first' /tmp/t1/run_megamind_windows.bat && ok "run.bat guards missing setup" || bad "run.bat missing setup guard"
grep -q 'curate_models.py' /tmp/t1/setup_megamind_windows.bat && grep -q 'wgp_config.template.json' /tmp/t1/setup_megamind_windows.bat && ok "setup.bat runs curation and seeds config" || bad "setup.bat missing curation/config steps"

# 7. Notices preserved; header Megamind-only
grep -q 'WanGP Community License' /tmp/t1/LICENSE.txt && ok "LICENSE.txt intact" || bad "LICENSE.txt changed"
grep -q 'Megamind Studios' /tmp/t1/wgp.py && ! grep -q 'powered by WanGP' /tmp/t1/wgp.py && ok "header is Megamind-only, no powered-by" || bad "header patch wrong"
grep -q 'DeepBeepMeep' /tmp/t1/plugins/about/plugin.py && ok "About tab credits preserved" || bad "About credits missing"
grep -q '2026-10-21' /tmp/t1/megamind/MEGAMIND.md && ok "modification notice dated (license 4.1d)" || bad "modification notice missing date"

echo "== $PASS passed, $FAIL failed =="
[ $FAIL = 0 ]
