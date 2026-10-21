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
PINNED_FULL=fdc63bdf89358fb13c93cf6b38693fd89a859f00
HEAD_FULL=$(git -C "$SRC" rev-parse HEAD)
if [ "$HEAD_FULL" = "$PINNED_FULL" ]; then WRONG=$(git -C "$SRC" rev-parse --short "$PINNED_FULL~1" 2>/dev/null || true); else WRONG=$(git -C "$SRC" rev-parse --short HEAD); fi
if [ -z "$WRONG" ] || [ "$(git -C "$SRC" rev-parse "$WRONG" 2>/dev/null)" = "$PINNED_FULL" ]; then bad "no non-pinned commit available for guard test (shallow clone at pinned?)"; else
fresh "$WORK/t2" && cd "$WORK/t2" && git checkout -q -f "$WRONG"
OUT=$(bash "$APPLY_SH" "$PATCH" 2>&1); RC=$?
if [ $RC -ne 0 ] && echo "$OUT" | grep -q "$PINNED"; then ok "apply_patch.sh refuses non-pinned commit $WRONG (exit $RC, names $PINNED)"; else bad "apply_patch.sh guard broken (exit $RC): $OUT"; fi
fi

# 3. apply_patch.sh APPLIES onto the pinned commit (real helper path)
fresh "$WORK/t3" && cd "$WORK/t3" && git checkout -q -f $PINNED
if bash "$APPLY_SH" "$PATCH" >/dev/null 2>&1 && [ -f megamind/ensure_config.py ]; then ok "apply_patch.sh applies onto $PINNED"; else bad "apply_patch.sh failed onto $PINNED"; fi

# 4. Curation on the patched tree: 268 hidden, exactly 4 visible
cd "$WORK/t1" && rm -rf finetunes && mkdir -p finetunes
echo '{"model":{"visible":false}}' > finetunes/t2v_1.3B.json   # stale stub from the pre-switch curation
"$PY" megamind/curate_models.py >/dev/null
missing=0; visible=0
for f in defaults/*.json; do
  mt=$(basename "$f" .json); stub="finetunes/$mt.json"
  case "$mt" in t2v_1.3B|flux2_klein_4b|chatterbox|ace_step_v1_5)
    [ -f "$stub" ] && bad "allowlisted $mt got a hiding stub" || visible=$((visible+1));;
  *) { [ -f "$stub" ] && grep -q '"visible": false' "$stub"; } || { missing=$((missing+1)); bad "stub missing: $mt"; };;
  esac
done
[ "$missing" = 0 ] && [ "$visible" = 4 ] && ok "curation: all non-curated hidden, exactly 4 visible, stale allowlisted stub removed" || bad "curation wrong: $missing missing stubs, $visible visible"

# 5. Config template: valid JSON, allowlist, megamind theme, ti2v_2_2 default
"$PY" - "$WORK/t1" <<'PYEOF' && ok "wgp_config.template.json valid" || bad "config template invalid"
import json,sys
c=json.load(open(sys.argv[1]+"/megamind/wgp_config.template.json"))
assert c.get("transformer_types")==["t2v_1.3B","flux2_klein_4b","chatterbox","ace_step_v1_5"]
assert c.get("UI_theme")=="default", "megamind theme is gone (plugin replaced it); template must seed default"
assert c.get("enabled_plugins")==["motion_designer","megamind"]
assert c.get("last_model_type")=="t2v_1.3B"
PYEOF

# 6. Patch is add-only: no upstream file is modified (plugin replaced all core edits)
cd "$WORK/t1" && git checkout -q -- . 2>/dev/null
if [ -z "$(git status --porcelain | grep -v '^??')" ]; then ok "patch adds files only - zero upstream code changes"; else bad "patch modifies upstream files: $(git status --porcelain | grep -v '^??' | head -3)"; fi

# 7. Branding plugin: files present, valid, wired through WanGP's plugin API
PDIR="$SCRIPT_DIR/megamind-plugin"
[ -f "$PDIR/plugin.py" ] && [ -f "$PDIR/plugin_info.json" ] && [ -f "$PDIR/__init__.py" ] \
  && ok "plugin package present (plugin.py, plugin_info.json, __init__.py)" || bad "plugin package incomplete"
"$PY" -c "import py_compile,sys; py_compile.compile(sys.argv[1], cfile='/tmp/mm_plugin_check.pyc', doraise=True)" "$PDIR/plugin.py" && ok "plugin.py compiles" || bad "plugin.py syntax error"
"$PY" - "$PDIR" <<'PYEOF' && ok "plugin wiring: WAN2GPPlugin subclass, add_custom_js, logo, light/dark toggle, pill tabs" || bad "plugin wiring markers missing"
import json,sys
d=sys.argv[1]
info=json.load(open(d+"/plugin_info.json")); assert info.get("name"), info
src=open(d+"/plugin.py",encoding="utf-8").read()
for marker in ("WAN2GPPlugin","add_custom_js","document.title","Megamind Studios","data:image","mm-mode","megamind_mode","mm-dark","tab-container","role=tab"):
    assert marker in src, marker
PYEOF

# 8. setup.bat: Git + Python checks, pinned checkout, pinned torch stack, no launcher overwrite
SB="$SCRIPT_DIR/setup_megamind_windows.bat"
g() { grep -q -- "$1" "$SB"; }
g "where git" && g "py -3.10" && g "checkout %PINNED%" \
  && g "torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1" \
  && g "findstr /V /I /C:" \
  && g 'requirements_megamind.txt' \
  && ok "setup.bat: git/python checks, pinned checkout, pinned torch stack, torchcodec excluded (documented)" || bad "setup.bat missing required logic"
if grep -q "torchcodec==0.5.0" "$SB"; then bad "setup.bat pins torchcodec 0.5.0 (no Windows wheel exists)"; else ok "setup.bat has no unshippable torchcodec pin"; fi
g 'xcopy /E /I /Y "%~dp0megamind-plugin"' && grep -qF 'plugins\megamind\plugin.py' "$SB" \
  && ok "setup.bat installs the branding plugin (xcopy + verify)" || bad "setup.bat missing plugin install"
g "pip install --upgrade pip" && g 'typing-extensions>=4.10' \
  && ok "setup.bat pre-installs typing-extensions from PyPI (cu128 index sdist trap, found by CI run 2)" || bad "setup.bat missing typing-extensions pre-install"
g "--index-url https://download.pytorch.org/whl/cu128" && ! grep -q "force-reinstall" "$SB" \
  && ok "setup.bat keeps the binary-verified torch rail (stable cu128 Windows wheel contains sm_61; no unverified index switch)" || bad "setup.bat torch rail changed without evidence"
if grep -q "^echo @echo off>" "$SB"; then bad "setup.bat overwrites the guarded launcher"; else ok "setup.bat preserves the guarded launcher"; fi

# 9. Final installed launcher is the guarded one from the patch
grep -q "Setup not done yet" "$WORK/t1/run_megamind_windows.bat" \
  && ok "installed run_megamind_windows.bat carries the setup guard" || bad "installed launcher missing setup guard"

# 10. License and notices
cmp -s "$WORK/t1/LICENSE.txt" "$SRC/LICENSE.txt" 2>/dev/null || diff <(git -C "$SRC" show $PINNED:LICENSE.txt) "$WORK/t1/LICENSE.txt" >/dev/null \
  && ok "LICENSE.txt intact" || bad "LICENSE.txt changed"
grep -q 'document.title="Megamind Studios"' "$SCRIPT_DIR/megamind-plugin/plugin.py" \
  && ok "plugin sets Megamind Studios title and logo header" || bad "plugin branding check failed"
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

# 12. GTX 1060 6GB seeds: int8 quants, low-VRAM profiles, auto attention
"$PY" - "$WORK/t1" <<'PYEOF' && ok "template seeds GTX 1060 profile (int8 quants, profile 4/3, auto attention)" || bad "template GTX 1060 seeds wrong"
import json,sys
c=json.load(open(sys.argv[1]+"/megamind/wgp_config.template.json"))
assert c.get("transformer_quantization")=="int8", "transformer_quantization must be int8 (Pascal: no fp8 hardware)"
assert c.get("text_encoder_quantization")=="int8"
assert c.get("attention_mode")=="auto"
assert c.get("profile")==4 and c.get("video_profile")==4 and c.get("image_profile")==4, "LowRAM_LowVRAM profile 4 required for 6GB"
assert c.get("audio_profile")==3, "LowRAM_HighVRAM profile 3 is upstream-recommended for audio"
PYEOF

# 13. Curated models ship Pascal-runnable quant artifacts in pinned upstream (no fp8-only models)
"$PY" - "$WORK/t1" <<'PYEOF' && ok "curated model artifacts Pascal-runnable (1.3B plain, klein/ace int8), none fp8-only" || bad "curated model quant artifacts wrong"
import json,sys
d=sys.argv[1]+"/defaults/"
def urls(f): return json.load(open(d+f)).get("model",{}).get("URLs",[])
t1=urls("t2v_1.3B.json");     assert len(t1)==1 and "1.3B" in t1[0], t1  # 1.3B runs unquantized FP16 on Pascal; no int8 variant exists
kl=urls("flux2_klein_4b.json"); assert any("quanto" in u and "int8" in u for u in kl), kl
ace=urls("ace_step_v1_5.json"); assert any("quanto" in u and "int8" in u for u in ace), ace
cb=urls("chatterbox.json");     assert len(cb)==1, cb
for name,u in [("t2v_1.3B",t1),("flux2_klein_4b",kl),("ace_step_v1_5",ace),("chatterbox",cb)]:
    assert not all("fp8" in x for x in u), name+" is fp8-only - not Pascal-runnable"
PYEOF

# 14. Pinned upstream auto-falls back to FP16 on Pascal (sm < 8.0) and defaults to int8 quant
grep -q 'if  gpu_major < 8:' "$WORK/t1/wgp.py" && grep -q 'bfloat16_supported = False' "$WORK/t1/wgp.py" \
  && ok "upstream auto FP16 fallback for Pascal present" || bad "upstream Pascal FP16 fallback missing"
grep -q '"transformer_quantization": "int8"' "$WORK/t1/wgp.py" \
  && ok "upstream default quantization is int8 (matches template)" || bad "upstream default quant changed"

# 15. Existing-install config migration: seeds when absent, enforces GTX 10xx fields, preserves user settings, idempotent
grep -qF 'python megamind\ensure_config.py' "$SB" && ok "setup.bat runs ensure_config.py migration" || bad "setup.bat missing config migration"
"$PY" - "$WORK/t1" <<'PYEOF' && ok "ensure_config: seed/migrate/preserve/idempotent" || bad "ensure_config migration wrong"
import json, os, subprocess, sys, tempfile
work = tempfile.mkdtemp()
os.makedirs(os.path.join(work, "megamind"))
for f in ("ensure_config.py", "wgp_config.template.json"):
    import shutil; shutil.copy(os.path.join(sys.argv[1], "megamind", f), os.path.join(work, "megamind", f))
run = lambda: subprocess.run([sys.executable, "megamind/ensure_config.py"], cwd=work, capture_output=True, text=True)
cfgp = os.path.join(work, "wgp_config.json")
r = run(); assert r.returncode == 0 and os.path.exists(cfgp), r.stderr
c = json.load(open(cfgp)); assert c["transformer_quantization"] == "int8" and c["profile"] == 4
c.update({"transformer_quantization": "fp8", "profile": 2, "image_profile": 1, "audio_profile": 5, "custom_key": "keep", "transformer_types": ["qwen_image_20B"], "last_model_type": "ti2v_2_2", "UI_theme": "megamind", "enabled_plugins": ["motion_designer"]})
json.dump(c, open(cfgp, "w"))
r = run(); assert r.returncode == 0, r.stderr
c = json.load(open(cfgp))
assert c["transformer_quantization"] == "int8" and c["profile"] == 4 and c["image_profile"] == 4
assert c["audio_profile"] == 5 and c["custom_key"] == "keep"
assert c["UI_theme"] == "default", "stale megamind theme must migrate to default"
assert c["enabled_plugins"] == ["motion_designer", "megamind"], "existing plugins must be preserved"
assert c["transformer_types"] == ["t2v_1.3B", "flux2_klein_4b", "chatterbox", "ace_step_v1_5"]
assert c["last_model_type"] == "t2v_1.3B", "stale last_model_type must migrate to the template default"
assert "megamind" in c["enabled_plugins"], "migration must enable the megamind plugin"
r = run(); assert "no changes" in r.stdout, r.stdout
c["profile"] = 4.5; json.dump(c, open(cfgp, "w"))
run(); assert json.load(open(cfgp))["profile"] == 4.5
PYEOF

# 16. Update-path branch logic: converted installs skip; old theme-patch and partial installs re-apply
SB="$SCRIPT_DIR/setup_megamind_windows.bat"
grep -qF 'if exist megamind\ensure_config.py if exist plugins\megamind\plugin.py findstr /C:"Megamind Studios" wgp.py >nul 2>&1 || set MM_SKIP=1' "$SB" \
  && ok "setup.bat skip condition covers old theme-patch installs" || bad "setup.bat skip condition wrong"
mm_skip() { local d="$1"; [ -f "$d/megamind/ensure_config.py" ] && [ -f "$d/plugins/megamind/plugin.py" ] && ! grep -q "Megamind Studios" "$d/wgp.py"; }
fresh "$WORK/t3" && cd "$WORK/t3" && git checkout -q -f $PINNED && git apply "$PATCH"
mkdir -p plugins/megamind && cp "$SCRIPT_DIR/megamind-plugin/plugin.py" "$SCRIPT_DIR/megamind-plugin/plugin_info.json" "$SCRIPT_DIR/megamind-plugin/__init__.py" plugins/megamind/
if mm_skip .; then ok "fully converted install skips re-apply (idempotent)"; else bad "skip path broken for converted install"; fi
echo 'REM Megamind Studios' >> wgp.py
if mm_skip .; then bad "old theme-patch install would be skipped"; else ok "old theme-patch install re-applies (core edit detected)"; fi
rm -rf plugins/megamind && git checkout -q -- wgp.py
if mm_skip .; then bad "missing plugin would be skipped"; else ok "missing plugin forces re-apply"; fi
rm -rf megamind plugins/megamind shared/gradio/ui_studio_megamind.css && rm -f run_megamind_windows.bat && git reset -q --hard $PINNED && git apply "$PATCH" \
  && [ -f megamind/ensure_config.py ] && ! grep -q "Megamind Studios" wgp.py \
  && ok "re-apply resets core and installs add-only patch" || bad "re-apply path broken"
cd "$SCRIPT_DIR"

echo "== $PASS passed, $FAIL failed =="
[ $FAIL = 0 ]
