# claude-code-hidden-features

A [Claude Code](https://claude.com/claude-code) skill that surfaces capabilities the product **under-surfaces**, then **triages** them against what you actually use — instead of leaving them drip-fed or buried in a binary.

Two modes, one thesis: the in-product surfaces are gimped (a small side-model drips tips one at a time; `--help` is truncated). A powerful main agent with your full history can mine the installed binary and rank what it finds for *you*.

- **Mode A — the tip catalog.** Claude Code's "daily tips" come from a fixed catalog (41 entries in 2.1.196) shown one-at-a-time by a small classifier that declines most of the time and only picks from a pre-filtered eligible subset. It can never tell you "here are the N you're missing." This extracts the whole catalog.
- **Mode B — undocumented CLI flags.** The binary defines ~74 flags; `claude --help` documents ~60. The rest (`--thinking-display`, `--bare`, `--max-budget-usd`, `--plan-mode-instructions`, …) are real but invisible. This diffs the binary's flag block against `--help`.

Both modes **re-extract per version** (nothing is hardcoded) and the output is always a **triage, not a list** — the 🔥 high-leverage few first, every item carrying a one-line evidence-grounded reason, the full set demoted to a collapsed reference.

## Install

Drop the directory into your Claude Code skills folder:

```bash
git clone https://github.com/evnchn-agentic/claude-code-hidden-features \
  ~/.claude/skills/claude-code-hidden-features
```

Then ask Claude Code something like *"extract all the Claude Code tips and screen the good ones"* or *"what undocumented flags is `--help` hiding?"*

## What's here

| File | Purpose |
|---|---|
| `SKILL.md` | The skill: procedure, triage contract, tier semantics, and the binary-mining gotchas. |
| `extract_catalog.sh` | Mode A — dumps the tip catalog from the installed binary (stable-string anchors, version-robust). |
| `extract_flags.sh` | Mode B — dumps the CLI flag block and the `--help`-omitted delta. |

Run either script directly (`./extract_catalog.sh` / `./extract_flags.sh`); both auto-locate the running version's binary, or take a path as `$1`.

## Gotchas it bakes in (each cost a real agent time)

- System `grep` may be **ugrep** → greedy `.\{0,N\}` windows abort with "exceeds complexity limits"; use `strings` + line-range `sed`.
- The binary embeds HTML/CSS-parser and bun/ripgrep help corpora → phrase-greps for "tip" drown in false positives. Anchor on feature_ids / the commander block.
- Modern Claude Code is a single ~220 MB Bun-compiled binary — there's no readable `cli.js`.
- Don't anchor on minified symbols (they change every build) — anchor on stable English strings.
- **Self-contamination:** the moment you dump extracted strings into chat, they land in the session log — so grepping transcripts for "usage" returns your own output. Exclude the current session; prefer shell history for true human-typed usage.

## Provenance

Built and verified (RED/GREEN, both extractors confirmed against 2.1.196) on macOS/arm64. Reverse-engineering of one's own installed CLI via `strings` is standard archaeology; none of this is security-sensitive, and the community already mirrors more (e.g. the full system prompt). Re-run per Claude Code version.

---

Part of [evnchn-agentic](https://github.com/evnchn-agentic) — agentic skills as reversible experiments.
