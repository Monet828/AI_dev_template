# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] -- hardening pass (targeting 0.2.0)

### Changed

- **`template/AGENTS.md` split for progressive disclosure: 415 lines -> 108.**
  AGENTS.md is injected into context on every single turn, so its size is a
  standing tax on every task regardless of what the task is. It had grown to
  ~4,600 tokens, of which roughly two thirds were procedures only needed at
  specific moments (how to write to `memory/`, how to run a long loop, how to
  scope a session) rather than rules that must hold at all times.

  The rules that must always hold stayed in AGENTS.md: source-of-truth order,
  implementation conventions, fact/interpretation separation, verification,
  standard commands, prohibitions, stop conditions, and git governance. The
  procedures moved into five new skills under `template/skills/`, loaded only
  when relevant:

  - `managing-memory` -- what goes in `memory/*`, and the promotion ladder to `docs/`
  - `session-bootstrap` -- what to read at start, goal-bounded autonomy, closing a session
  - `recording-decisions` -- required elements of a design decision, and where it lives
  - `reviewing-changes` -- review checklist and how to report findings
  - `running-loops` -- loop state, step/retry budgets, `Resume From` handoffs

  Standing context cost drops from ~4,614 to ~2,441 tokens (-47%), counting the
  five new skill descriptions that are preloaded at startup. No content was
  deleted; it was relocated and, in places, tightened.

  All five skills conform to Anthropic's published Agent Skills limits: `name`
  <= 64 chars (lowercase/digits/hyphens), `description` <= 1,024 chars, body
  under 500 lines, and references kept one level deep from SKILL.md.

  Existing skills (`code-review`, `evidence-first-repro`,
  `saas-research-to-prototype`) were already within those limits and are
  unchanged.

- **New skill: `delegating-to-codex`.** Decides whether to hand a task to the
  OpenAI Codex CLI instead of running it in the current session, and how to run
  it when the answer is yes. Most of the skill exists to say no: it opens with
  measured numbers showing that delegation is usually the wrong call.

  The routing rules are grounded in a three-arm experiment (same three tasks run
  by Claude directly, by a Claude subagent, and by `codex exec`) rather than in
  intuition. Measured token consumption:

  | task | direct | subagent | Codex |
  |---|---|---|---|
  | 21 files, 1,215 lines | 12,480 | 45,588 | 204,149 |
  | 4 files, 40KB | 11,512 | 50,257 | 164,926 |
  | 1 file, 110 lines | 1,038 | 35,751 | 99,076 |

  Three findings drive the skill's content. Reading one small file costs 34x
  more via subagent and 95x more via Codex than just reading it. Parent-context
  savings are effectively identical between subagent (~2,000 returned) and Codex
  (~1,400) on the largest task, so context savings alone do not justify
  delegation. And Codex spent 3.6x the total tokens for the same three tasks,
  because it re-runs search commands -- delegation moves quota consumption
  rather than reducing it.

  The skill therefore permits delegation only when Claude's own usage limit is
  the binding constraint, when a second model's review is genuinely wanted
  (`codex exec review --uncommitted`), or when a long task should run alongside
  other work. Write delegation is explicitly out of scope; read-only with an
  explicit `--sandbox read-only` is the documented path, verified to produce
  zero file modifications in the experiment.

  Also documents the fixed ~22,000-token overhead per `codex exec` call, that
  `error` items are not necessarily failures, and that injecting `-c notify=`
  per job (as some third-party orchestrators do) overwrites a user's existing
  `~/.codex/config.toml` notify hook.

  Structurally the skill borrows from three existing orchestrators rather than
  inventing a shape: the task/report contract and the "a refuted premise is a
  successful result, not a bug to fix" rule come from `h-wata/squad`'s
  `task.yaml` / `report.yaml`; parallel dispatch and the error-recovery table
  come from `kingbootoshi/codex-orchestrator`. What is not borrowed is the
  routing: those tools delegate by default, and the measurements above say
  that is wrong for this template's usage, so the routing table sends most
  work back to reading directly or to a Claude subagent.

- **`template/AGENTS.md` gains a section on not flooding context** (new §5;
  later sections renumbered, and the three skill cross-references into
  AGENTS.md were re-checked against the new numbering). Long output goes to a
  file and is read back selectively; failed runs are read from the tail;
  exploration goes to a subagent. The subagent point carries the measurement
  that justifies it — 21 files investigated cost 45,588 tokens inside the
  subagent and returned about 2,000 to the parent.

- **`template/agents/researcher.md` gains a "how to report back" section.**
  The role previously defined what to collect but not what to return, which
  left the context firewall to chance: a researcher that pastes its search
  output into the parent has done nothing except add a hop. It now requires
  conclusions rather than logs, `path:line` citations instead of quoted
  bodies, an explicit "not found" rather than a silent omission or a
  near-miss substitute, and the same read-it-versus-verified-it distinction
  AGENTS.md §3 requires.

- **`evidence-first` pack gains an Evidence Card** at
  `docs/templates/evidence-card.md`, required before filing work whose
  premise is an observed number (log/metric aggregates, DB counts and
  inventories). Seven fields: the claim, when it was observed, the data
  window, what the metric actually counts, what a pre-filing check of
  git log / merged PRs / CHANGELOG / ADRs found, the cheapest way to refute
  the claim, and what happens to the work if it is refuted.

  The template carries a worked example of a real filing that turned out to
  be wrong — a "duplicate writes" bug where 132 was a raw row count and 77
  was a logical count excluding superseded rows, so the gap was two different
  semantics rather than duplication. Two fields would have caught it before
  any work started.

  It also states the rule that makes refutation cheap to report: a refuted
  premise is the successful outcome, the work stops there, and no follow-up
  fix task is created from it.

### Breaking changes

- **`scripts/setup/doctor.sh` now returns a real exit code.** It previously
  had no `exit` statements at all and always exited 0 regardless of how many
  required files were missing. It now exits 1 if any hard-required path is
  missing, 0 otherwise (warnings never affect the exit code). If anything
  scripted around this tool assuming it always succeeds, that assumption no
  longer holds -- this was the fix, not a side effect.
- **Generated projects are now sourced from `template/`, not the repo
  root.** `scripts/setup/scaffold.sh` and `scripts/setup/new-project.sh`
  (the generator itself), `packs/`, and `tests/` (this repo's own test
  suite) are no longer copied into generated projects -- they never worked
  correctly there anyway (a copied `scaffold.sh` had no `packs/` sibling and
  failed immediately if run). If you scripted around the old behavior of a
  generated project containing a working `scaffold.sh`, it's gone
  intentionally.
- **`scripts/loop/verify.sh` now runs real checks instead of printing a
  checklist.** The old behavior (a static review checklist plus an optional
  interactive self-report appended to the session log) is preserved
  unchanged under a new name: `scripts/loop/record-verification.sh`.

### Added

- `template/` as the generation source root, separated from generator-only
  tooling (`scripts/setup/{scaffold,new-project}.sh`, `packs/`, `tests/`,
  this repo's own README/CONTRIBUTING/SECURITY/CHANGELOG/CI).
- `tests/regression/`: a lightweight, dependency-free Bash test harness
  (`run.sh` + `lib/assert.sh` + `cases/*.sh`) covering profile generation,
  pack application (including duplicates), non-destructive/transactional
  generation, space-in-path targets, `doctor.sh` exit codes, and `verify.sh`
  behavior.
- `doctor.sh --json`, emitting `{status, passed, warnings, errors, checks}`
  with no human-readable text mixed in.
- Transactional generation: `scaffold.sh` now builds in a `mktemp` staging
  directory and only moves it into place once every step succeeds. A
  failure partway leaves no partial target directory.
- `.ai-dev-template.yml`, written into every generated project, recording
  `schema_version`, `template_version` (from the new root `VERSION` file),
  `profile`, `installed_packs` (real per-pack versions), and `created_at`.
- `.github/workflows/ci.yml` (replacing `shell.yml`): shell syntax +
  shellcheck, the regression suite, and a per-profile generation-and-doctor
  check, each on an `ubuntu-latest`/`macos-latest` matrix.
- `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md` (this file's sibling
  documenting the pack-manifest `source` risk and the "no git hook exists"
  fact), and this `CHANGELOG.md`.
- `template/LICENSE` (MIT, placeholder copyright), so a generated project
  ships with its own license from day one.

### Fixed

- Requesting the same pack twice in `--with a,a` previously duplicated its
  `append/` content into the target file; duplicates are now skipped.
- `packs/problem-first` shipped its own `merge/scripts/loop/verify.sh`,
  which would have silently overwritten the new real verify.sh with its old
  checklist variant whenever that pack was applied. Renamed to
  `merge/scripts/loop/record-verification.sh`, which is what it actually
  customizes.
- All 26 pre-existing shellcheck warnings (measured with shellcheck 0.11.0
  across every `*.sh` in the repo).
- A latent "unbound variable" crash under `set -u` on bash 3.2 (macOS's
  stock `/bin/bash`) if `copy_base_template`'s source directory ever had
  zero top-level entries -- never triggered in practice, but fixed while
  touching the same code for transactional generation.
