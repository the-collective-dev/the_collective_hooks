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
set -euo pipefail
LC_ALL=C
export LC_ALL

FAILS=0; WARNS=0; STRICT=0
fail() { echo "::error file=$1,line=$2::FORTKNOX: $3"; FAILS=$((FAILS+1)); }
warn() { echo "::warning file=$1,line=$2::FORTKNOX: $3"; WARNS=$((WARNS+1)); }

# Bidi Trojan-Source overrides: U+202A-E, U+2066-9.
BIDI_RE=$'[\xe2\x80\xaa-\xe2\x80\xae\xe2\x81\xa6-\xe2\x81\xa9]'

# Executable-config surface (where an injected payload hides + auto-runs).
config_files() {  # $1 = root ; prints NUL-separated paths
  find "$1" \( -name .git -o -name node_modules -o -name dist -o -name build \
      -o -name .next -o -name coverage -o -name target \) -prune -o \
    \( -name '*.config.js' -o -name '*.config.cjs' -o -name '*.config.mjs' \
       -o -name '*.config.ts' -o -name 'next.config.*' -o -name 'postcss.config.*' \
       -o -name 'tailwind.config.*' -o -name 'vite.config.*' -o -name 'svelte.config.*' \
       -o -name '.eslintrc*' -o -name 'rollup.config.*' -o -name 'webpack.config.*' \) \
    -type f -print0 2>/dev/null
}

scan() {
  local root="${1:-.}" f l hits
  echo "FORTKNOX public preflight: scanning $root (heuristics only, no signatures)"

  # ---- executable-config heuristics ----
  while IFS= read -r -d '' f; do
    # config-injection obfuscation combo -> FAIL (fromCharCode join + global assign)
    if grep -qE 'String\.fromCharCode' -- "$f" 2>/dev/null && grep -qE 'global\[[^]]+\][[:space:]]*=' -- "$f" 2>/dev/null; then
      l=$(grep -nE 'global\[[^]]+\][[:space:]]*=' -- "$f" | head -1 | cut -d: -f1)
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
    hits=$(grep -nHE '"(preinstall|install|postinstall|prepare|prepublish|prepublishOnly)"[[:space:]]*:' -- "$f" 2>/dev/null || true)
    [ -n "$hits" ] && warn "$f" "$(echo "$hits"|head -1|cut -d: -f1)" "package.json lifecycle hook (runs on npm install) — review it"
  done < <(find "$root" \( -name node_modules -o -name .git \) -prune -o -name 'package.json' -type f -print0 2>/dev/null)

  # ---- repo-wide: curl|sh, bidi ----
  hits=$(find "$root" \( -name .git -o -name node_modules \) -prune -o -type f \
    -exec grep -nHIE 'curl[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' -- {} + 2>/dev/null || true)
  [ -n "$hits" ] && while IFS= read -r h; do warn "$(echo "$h"|cut -d: -f1)" "$(echo "$h"|cut -d: -f2)" "curl piped to shell — fetch-and-execute, needs review"; done <<<"$hits"
  hits=$(find "$root" \( -name .git -o -name node_modules \) -prune -o -type f \
    -exec grep -nHIE "$BIDI_RE" -- {} + 2>/dev/null || true)
  [ -n "$hits" ] && warn "$(echo "$hits"|head -1|cut -d: -f1)" "1" "Trojan-Source bidirectional-override character"

  # ---- prohibited surfaces -> FAIL ----
  [ -f "$root/.mcp.json" ] && fail "$root/.mcp.json" 1 "repo-root .mcp.json — prohibited auto-loaded MCP surface"
  [ -f "$root/.cursor/mcp.json" ] && fail "$root/.cursor/mcp.json" 1 "repo-root .cursor/mcp.json — prohibited auto-loaded MCP surface"
  while IFS= read -r -d '' f; do
    if grep -qE '"?runOn"?[[:space:]]*:[[:space:]]*"?folderOpen' -- "$f" 2>/dev/null; then
      l=$(grep -nE 'folderOpen' -- "$f" | head -1 | cut -d: -f1)
      fail "$f" "${l:-1}" "editor task auto-runs on folderOpen — executes on open, no build required"
    fi
  done < <(find "$root" -path '*/.vscode/tasks.json' -type f -print0 2>/dev/null)
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
