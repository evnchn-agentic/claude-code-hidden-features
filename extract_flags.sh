#!/usr/bin/env bash
# Extract the FULL CLI flag block from the installed Claude Code binary and diff it
# against `claude --help`, surfacing flags the help text omits (e.g. --thinking-display).
# Version-robust: anchors on stable English, never on offsets. Re-run per CC version.
#
# Usage: ./extract_flags.sh [path-to-binary]
set -uo pipefail

BIN="${1:-}"
if [ -z "$BIN" ]; then
  REAL="$(readlink -f "$(command -v claude 2>/dev/null)" 2>/dev/null || true)"
  if [ -n "$REAL" ] && [ -f "$REAL" ]; then BIN="$REAL"; else
    VDIR="$HOME/.local/share/claude/versions"
    [ -d "$VDIR" ] && BIN="$(ls -t "$VDIR" 2>/dev/null | head -1 | sed "s|^|$VDIR/|")"
  fi
fi
[ -n "$BIN" ] && [ -f "$BIN" ] || { echo "ERROR: could not locate the Claude Code binary. Pass it as \$1." >&2; exit 1; }
echo "# binary: $BIN" >&2

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
strings -n 4 "$BIN" > "$TMP"

# The commander flag block is one contiguous region. Anchor on the program tagline
# (start) and the first end marker after it: the issues-URL footer (2.1.196) or the
# `run_main_options_built` checkpoint (2.1.308+, where the footer no longer follows).
START_RE='Claude Code - starts an interactive session by default'
s=$(grep -n "$START_RE" "$TMP" | head -1 | cut -d: -f1)
# The footer is a generic error string used hundreds of times — take the FIRST match
# AFTER the flag block starts.
e=$(awk -v s="${s:-0}" 'NR>s && ($0=="run_main_options_built" || index($0,"report the issue at https://github.com/anthropics/claude-code/issues")){print NR; exit}' "$TMP")

# A real block is a few hundred lines. Anything bigger means the end marker matched far
# past the block, and the "undocumented" list would be every --word in the binary.
if [ -z "${s:-}" ] || [ -z "${e:-}" ] || [ "$e" -le "$s" ] || [ $((e - s)) -gt 1000 ]; then
  echo "WARN: anchors moved. Re-locate by grepping the binary strings for '--thinking-display'" >&2
  echo "      or 'Display help for command' and read the surrounding block." >&2
  exit 2
fi

echo "## Full CLI flag block (flag + description, verbatim from binary):"
sed -n "${s},${e}p" "$TMP"

echo; echo "## UNDOCUMENTED — in the binary's CLI block but NOT in \`claude --help\`:"
sed -n "${s},${e}p" "$TMP" | grep -oE '\-\-[a-z][a-z0-9-]+' | sort -u > "$TMP.cli"
"$BIN" --help 2>/dev/null | grep -oE '\-\-[a-z][a-z0-9-]+' | sort -u > "$TMP.help"
# Without its --help, every flag would be reported as undocumented.
[ -s "$TMP.help" ] || { echo "ERROR: '$BIN --help' printed no flags; cannot diff." >&2; exit 2; }
comm -23 "$TMP.cli" "$TMP.help"
rm -f "$TMP.cli" "$TMP.help"
echo "# (Read each flag's description in the block above before recommending it — some are SDK-internal/deep-link plumbing, not operator knobs. A lower bound: some builds declare hidden flags outside this block.)" >&2
