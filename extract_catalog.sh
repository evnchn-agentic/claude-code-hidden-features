#!/usr/bin/env bash
# Extract the full Claude Code context-tip catalog from the INSTALLED binary.
# Version-robust: anchors on stable English strings, never on the minified array
# symbol (e.g. $Vn) which changes every build. Re-run per CC version — do NOT cache.
#
# Usage: ./extract_catalog.sh [path-to-binary]
#   no arg -> auto-locates the running version's binary
set -uo pipefail

BIN="${1:-}"
if [ -z "$BIN" ]; then
  # `claude` is usually a launcher shim; the real binary is the versioned Mach-O/ELF.
  CLAUDE="$(command -v claude || true)"
  REAL="$(readlink -f "$CLAUDE" 2>/dev/null || true)"
  if [ -n "$REAL" ] && [ -f "$REAL" ]; then
    BIN="$REAL"
  else
    # fall back to newest file in the versions dir
    VDIR="$HOME/.local/share/claude/versions"
    [ -d "$VDIR" ] && BIN="$(ls -t "$VDIR" 2>/dev/null | head -1 | sed "s|^|$VDIR/|")"
  fi
fi
[ -n "$BIN" ] && [ -f "$BIN" ] || { echo "ERROR: could not locate the Claude Code binary. Pass it as \$1." >&2; exit 1; }
echo "# binary: $BIN  ($(du -h "$BIN" | cut -f1))" >&2

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
# strings is enough to READ the catalog. -n6 keeps short ids/actions while dropping noise.
strings -n 6 "$BIN" > "$TMP"

# The catalog DATA block (id / situation / feature / action lines) sits together,
# bracketed by the first tip's feature text and the response-schema sentinel that
# immediately follows the last entry. Both are stable English; the array symbol is not.
START_RE='MCP connects Claude directly'                 # mcp-discovery feature (first entry)
END_RE='Emit a contextual tip, or decline'              # response-schema sentinel (right after last entry)

s=$(grep -n "$START_RE" "$TMP" | head -1 | cut -d: -f1)
e=$(grep -n "$END_RE"   "$TMP" | head -1 | cut -d: -f1)

if [ -n "${s:-}" ] && [ -n "${e:-}" ] && [ "$e" -gt "$s" ]; then
  s=$((s > 1 ? s - 1 : s))   # back up 1: the first entry's id line precedes its feature text
  sed -n "${s},${e}p" "$TMP"
  echo "# --- catalog block: lines $s..$e of strings output ---" >&2
# 2.1.308+: the classifier catalog above is gone. Tips are minified object literals,
# {id:"...",content:...,cooldownSessions:N,...}. Ids are exact; the text is the longest
# string literal in `content` — best-effort, since some tips build their text in code.
elif tips="$(grep 'cooldownSessions:' "$TMP" | perl -ne 'for my $c (split /(?=\{id:")/) {
    next unless $c =~ /^\{id:"([a-z0-9-]+)"/ && $c =~ /cooldownSessions:/; my $id = $1;
    my ($b) = $c =~ /content:(.*?)cooldownSessions:/s;
    my ($t) = sort { length $b <=> length $a } ($b // "") =~ /("(?:[^"\\]|\\.)*"|`[^`]*`)/g;
    print "id: $id\n  ", $t // "(text built in code)", "\n" }')" && [ -n "$tips" ]; then
  printf '%s\n' "$tips"
  echo "# tip catalog (2.1.308+ shape): $(printf '%s\n' "$tips" | grep -c '^id:') tips; id exact, text best-effort" >&2
else
  echo "WARN: anchors moved (CC build changed the wording). Fallback: showing the" >&2
  echo "      classifier prompt + nearby region so you can re-locate the catalog by hand." >&2
  echo "      Stable landmarks to grep for: 'The catalog below lists all tips'," >&2
  echo "      '<eligible_ids>', 'rate_tip_reception', and known feature_ids like" >&2
  echo "      'correction-spiral' / 'side-question-during-work'." >&2
  grep -n 'The catalog below lists all tips\|<eligible_ids>\|rate_tip_reception\|correction-spiral' "$TMP" >&2
  exit 2
fi
