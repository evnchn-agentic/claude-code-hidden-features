---
name: claude-code-hidden-features
description: Use when the operator wants Claude Code capabilities the product under-surfaces — the drip-fed "daily tips"/spinner tips surfaced ALL at once, OR undocumented CLI flags that `claude --help` omits (e.g. `--thinking-display summarized`). Also "what CC features am I missing", "screen the good tips", "what hidden/undocumented flags exist", "what's not in --help". Triggers: extract all claude code tips, full tip catalog, context-tips, spinner tips, hidden flags, undocumented flags, secret flags, --help is incomplete, claude code internals.
---

# Claude Code hidden features — surface what the product under-surfaces, then triage

## Overview

Claude Code under-surfaces its own capability in two ways, and the same powerful-main-agent move fixes both:

- **Mode A — drip-fed tips.** A fixed catalog (41 in 2.1.196) is shown one-at-a-time by a *small* side-model that sees only the current session, picks from a pre-filtered eligible subset, and declines most turns. It can never say "here are the N you're missing."
- **Mode B — `--help`-hidden flags.** The binary's CLI defines ~74 flags; `--help` documents ~60. The rest (`--thinking-display`, `--bare`, `--max-budget-usd`, `--plan-mode-instructions`, …) are real but invisible.

**The unifying thesis:** the in-product surfaces are gimped (small model / truncated help). The main agent — powerful, with the operator's full JSONL + memory + settings — mines the **installed binary** and **triages** what it finds against what this operator actually does. That's the value the product can't deliver.

**Core principle: re-extract per version, never hardcode.** Both the catalog and the flag set change every build. The durable asset is the extraction + triage procedure, not last month's list.

## Deliverable contract (this is the whole point — read before doing anything)

**The output is a TRIAGE, not a list.** A flat dump of all N tips/flags is the failure this skill exists to prevent — re-printing what extraction returns adds **zero** value. Value is created *only* by triaging against this operator's evidence.

The deliverable, in order:
1. **The 🔥 set first** — the handful (typically 5–10) that are non-obvious AND high-leverage AND that evidence shows the operator does NOT already use / would benefit from.
2. **A one-line, evidence-grounded reason on EVERY item** — why this tier, citing what you found in their JSONL / settings.json / memory (not vibes, not "power users know this").
3. **The full N only as a demoted, collapsed, tier-tagged reference table** — present, never the lead.

If you produced an untiered list, or tiers without per-item evidence, or led with the full table — you did the thing this skill forbids. Start over from the screening step.

## Shared substrate

Both modes: locate the **installed binary** (`~/.local/share/claude/versions/<ver>`, a ~220 MB Bun-compiled Mach-O/ELF — there is no readable `cli.js`), `strings`-mine it, anchor on **stable English**, then triage against the operator's real usage:

```bash
# what slash-commands / flags does this operator already use?
grep -rhoE '<command-name>[^<]+' ~/.claude/projects/*/*.jsonl 2>/dev/null | sort | uniq -c | sort -rn   # typed slash-commands (ground truth)
grep -rhoE '\-\-[a-z][a-z0-9-]+' ~/.claude/projects/*/*.jsonl 2>/dev/null | sort | uniq -c | sort -rn   # flags seen in transcripts
grep -rilE 'worktree|subagent|bypass|overnight|ultracode|mcp|autoMode' ~/.claude/projects/*/memory/ 2>/dev/null
cat ~/.claude/settings.json 2>/dev/null   # what's already configured (statusLine, autoMode, hooks, spinnerTipsEnabled…)
```
Prefer `<command-name>` JSONL tags as ground truth — raw substring counts (e.g. `/memory ×18k`) are inflated by file-paths; discard them.

**⚠️ Self-contamination (burned live 2026-06-30):** the moment you `strings`-dump tips/flags into chat, that text lands in the **current session's JSONL** — so grepping transcripts for those very tokens returns *your own output*, not the operator's usage. Always **exclude the current session file** (`for f in …/*.jsonl; do case "$f" in *$CUR*) continue;; esac; …`), and treat even other-session *mentions* as discussion, not invocation. The **cleanest human-invocation signal is shell history** (`~/.zsh_history` / `~/.bash_history`), where you see what the operator actually typed — e.g. a handful of flags dominating while the "gold" ones are absent → genuinely unused.

## Mode A — the tip catalog

```bash
~/.claude/skills/claude-code-hidden-features/extract_catalog.sh
```
Prints the catalog block: repeating `id` / `situation` / `feature` / `action` lines. **Input for triage, never the deliverable.** Tier each tip: 🔥 banger · ✅ situational · 💤 already-live (name it so they skip) · 🚫 N/A (the local `when()` gate would never surface it for them — e.g. Pro-plan-only tips for an API user). Kill switch to mention: `"spinnerTipsEnabled": false`.

## Mode B — undocumented CLI flags

```bash
~/.claude/skills/claude-code-hidden-features/extract_flags.sh
```
Prints the full flag+description block, then the `--help`-omitted delta. **Read each flag's description before recommending it** — the delta mixes operator gold with plumbing. Tier semantics differ from tips:

| Tier | Meaning | examples (2.1.196) |
|---|---|---|
| 🔥 gold | high-leverage operator knob `--help` hides | `--bare`, `--max-budget-usd`, `--thinking-display summarized`, `--plan-mode-instructions`, `--exclude-dynamic-system-prompt-sections`, `--task-budget` |
| ✅ situational | useful in specific workflows | `--fork-session`, `--rewind-files`, `--from-pr`, `--betas`, `--prefill`, `--resume-session-at` |
| ⚙️ internal / ignore | SDK/deep-link plumbing, not for humans | `--session-mirror`, `--deep-link-*`, `--managed-settings`, `--workload`, `--reply-on-resume` |
| ⚠️ footgun | powerful + dangerous; caveat required | `--dangerously-skip-permissions` (documented), `--no-session-persistence` |

## Deliver as a rich-render dashboard (triage shape)

Lead with the verdict + 🔥 set; then ✅; then 💤/⚙️ named so they can skip; full table tagged-by-tier **last, inside `<details>`**. **REQUIRED SUB-SKILL:** use `rich-render`. If both modes were run, two sections (Tips / Flags) under one dashboard.

## Gotchas (each cost a fresh agent real time)

| Trap | Reality / fix |
|---|---|
| `grep -a -o '.\{0,8000\}…'` for a big window | System `grep` is **ugrep** → "exceeds complexity limits"; `.` doesn't cross newlines → **0 bytes**. Use `strings` + line-range `sed` (what the helpers do). |
| Greedy phrase-grep for `tip` / a flag word | Binary embeds HTML/CSS-parser + bun/ripgrep help corpora → hundreds of false hits. Anchor on feature_ids / the commander block, not loose words. |
| A common anchor string (`report the issue at…` ×216, generic error msgs) | `head -1` grabs one *before* your block. Take the first match **after** the start line (see `extract_flags.sh`). |
| Assuming tips are model-generated / flags are all in `--help` | There IS a static catalog; there ARE ~14+ `--help`-omitted flags. Verify by extraction, don't assume. |
| Anchoring on a minified symbol (`$Vn`) | Changes every build. Anchor on stable English. |
| Piebald-AI mirror | Mirrors the system *prompt*, not the catalog or flag block. Extract from the local binary. |

## Architecture notes

- Spinner tips + contextual tips share one catalog (`spinnerTipsOverride` replaces the pool). Classifier prompt: "You are watching someone use Claude Code…", takes `<eligible_ids>`/`<ineligible_ids>`. A `rate_tip_reception` tool scores whether the operator acted. Catalog DATA and classifier PROMPT live in **different** binary regions.
- The CLI flag block is one contiguous commander region (program tagline → issues-URL footer). `extract_flags.sh` brackets exactly that.
- Not for general "can Claude do X?" docs questions (→ `claude-code-guide` agent) or behavioral-drift (→ `bisecting-claude-code-anomalies`).
