#!/usr/bin/env bash
# Check both extractors against one installed binary. Exits non-zero on any failure.
# Usage: ./selftest.sh [path-to-binary]
set -uo pipefail
cd "$(dirname "$0")"
BIN="${1:-}"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

flags="$(./extract_flags.sh "$BIN" 2>/dev/null)"; frc=$?
delta="$(printf '%s\n' "$flags" | sed -n '/^## UNDOCUMENTED/,$p' | tail -n +2)"
check "extract_flags.sh exits 0"                         '[ "$frc" -eq 0 ]'
check "flag output is a CLI block, not the whole binary" '[ "$(printf "%s\n" "$flags" | wc -l)" -lt 1000 ]'
check "delta has no non-CC flags (--zend-extension)"     '[ "$(printf "%s\n" "$delta" | grep -cx -- --zend-extension)" -eq 0 ]'
check "delta is non-empty"                               '[ -n "$delta" ]'
documented="$("${BIN:-claude}" --help 2>/dev/null | grep -oE '\-\-[a-z][a-z0-9-]+' | sort -u)"
check "this binary's --help lists flags"                 '[ -n "$documented" ]'
check "delta excludes flags this binary's --help shows"  '[ -z "$(comm -12 <(printf "%s\n" "$delta" | sort -u) <(printf "%s\n" "$documented"))" ]'

cat="$(./extract_catalog.sh "$BIN" 2>/dev/null)"; crc=$?
check "extract_catalog.sh exits 0"                       '[ "$crc" -eq 0 ]'
check "catalog lists at least 10 tips, each with an id"  '[ "$(printf "%s\n" "$cat" | grep -cE "^id: [a-z0-9-]+$")" -ge 10 ]'

exit $fail
