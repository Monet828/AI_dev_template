# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] -- hardening pass (targeting 0.2.0)

### Fixed

- **`scripts/codex/discover.sh` swallowed adjacent claims when markers had no
  blank line between them.** Found immediately on first real-world use: a
  densely bulleted README section marks every bullet with
  `<!-- codex:verify -->` back to back, no blank lines. The claim-absorption
  loop only stopped at a blank line, so it walked straight through the next
  marker and into the start of the next claim -- the original regression
  test only exercised blank-line-separated markers and missed this. The loop
  now also stops the instant it sees another marker. The test gained four
  adjacent, mixed single-line/wrapping claims to cover exactly this shape,
  and its later assertions (queue counts, pending counts) were hardcoded to
  the old 2-claim baseline and needed updating -- the final "drain to empty"
  check was also rewritten to actually drain the queue in a loop instead of
  assuming a fixed remaining count, since that count depends on how many
  earlier steps happen to consume an item.



- **`scripts/codex/discover.sh` and `scripts/codex/dispatch.sh` -- a two-layer
  design separating when to look from when to spend quota.** Prompted by a
  concrete question: is it worth firing Codex every 30 minutes so a Plus
  subscription's idle time isn't wasted? The premise doesn't hold -- Plus
  costs the same whether it's used or not, and delegation costs 3.6x the
  tokens of doing the work directly (measured in the `feat(codex)` PR), so
  filling idle time with low-value work is a net loss, not a gain. What
  actually paid off in practice was Codex checking a documented claim the
  author had no reason to go re-check themselves (folder-lens's README stated
  its secret-file policy was consolidated in one place; the search path had
  quietly duplicated it and drifted). That's a narrow, falsifiable class of
  task: does this specific claim hold against this specific code.

  `discover.sh` scans for an `<!-- codex:verify -->` marker followed by a
  claim, and appends new ones to `memory/codex-queue.jsonl`. **It never calls
  Codex** -- it only reads files and appends to the queue -- so it's safe to
  run on any schedule (cron, launchd, every 30 minutes, every 5) with zero
  quota cost. A claim's id hashes its file path and text, so editing a claim
  re-queues it under a new id while an unchanged, already-handled one is never
  queued twice.

  `dispatch.sh --list` shows what's pending; `--next` or `--id <ID>` pops one
  item, builds a fact-check task (confirm/deny this claim, not "improve this"),
  and hands it to `delegate.sh`. **This is the only operation that spends
  quota, and it only runs when a human runs it.** The verdict
  (`confirmed`/`falsified`/`uncertain`) and evidence are folded back into the
  queue entry. A `falsified` result is not a failure -- see the existing
  claims-are-not-failures rule in the skill's report contract.

  `skills/delegating-to-codex/SKILL.md` gains a new section 9 stating the
  design principle explicitly: **time-drive discovery, never time-drive
  delegation.** `docs/playbooks/codex-discovery-patrol.md` gives launchd and
  cron templates for `discover.sh` -- deliberately not for `dispatch.sh`.

  `tests/regression/cases/60_codex_discovery_queue.sh` (21 assertions, fake
  `codex` on PATH) proves discovery and delegation stay separated: discovery
  never invokes `codex`, even when one exists on PATH and would exit nonzero
  if called; a multi-line claim is joined correctly; an unchanged claim isn't
  re-queued while an edited one is; a failed delegation is recorded as
  `delegation_failed` rather than silently dropped; a read-only violation
  during dispatch leaves the queue entry untouched rather than corrupting it.



- **`template/scripts/codex/` -- the mechanical half of Codex delegation, as
  standard equipment.** The
  `delegating-to-codex` skill already decided *when* to delegate and what to
  require back, and its report contract says `status`, `files_modified`, and
  command exit codes must be derived mechanically rather than believed. Prose
  cannot make that true. Assembled by hand each time, those three fields
  quietly revert to the delegate's self-report -- which is the one thing the
  contract exists to prevent. This is the same two-layer split the repository
  already uses for git governance (`AGENTS.md` §9): the skill asks, the pack
  enforces.

  `scripts/codex/delegate.sh` runs one read-only investigation and returns a
  report where `status` comes from the process exit code, `files_modified`
  comes from comparing `git rev-parse HEAD` and `git status --porcelain`
  before and after, and `commands` with their exit codes are parsed out of the
  JSONL event stream. `report-schema.json` is passed to `--output-schema`, so
  the model's `claims` come back with a `confirmed | falsified | uncertain`
  status enforced by the tool rather than requested in prose. The full log is
  written to a file and only its path is returned.
  `scripts/codex/review.sh` wraps `codex exec review` the same way.

  These ship in `template/`, not as an opt-in pack. The `delegating-to-codex`
  skill was already standard equipment in every generated project, and pairing
  a rule that ships everywhere with an implementation that ships only on
  request produces the worst arrangement: the contract is always in context
  telling the agent those fields must be mechanical, while the thing that makes
  them mechanical is usually absent. `AGENTS.md` gains two lines in the
  standard-commands section and one stop condition (a `delegate.sh` exit 3 --
  files changed under a read-only sandbox -- means stop and report, not
  interpret the result).

  Three findings came out of building it, each verified against the real CLI
  rather than assumed:

  - **`codex exec` hangs on stdin.** Even with the prompt passed as an
    argument, invoking it from a non-interactive parent enters an input wait.
    Measured at 6m40s with no output and no error -- it presents as a hang,
    not a failure, so nothing detects it. Both scripts redirect `</dev/null`.
  - **`error` items are not failures.** A healthy run emits one carrying
    "Skill descriptions were shortened to fit the 2% skills context budget."
    Deciding status from the presence of `error` items reports working runs as
    broken, so status is taken from the exit code alone. The notices are still
    surfaced, never swallowed.
  - **The fixed overhead is larger than previously recorded.** Reading a single
    one-line `VERSION` file cost 43,826 input tokens (22,272 cached). The
    skill's routing table is updated with the measurement.

  The sandbox is `read-only` and cannot be overridden. Beyond the flag, the
  scripts verify the invariant themselves: if the tree changed, they exit 3
  and emit no report rather than returning results from a run whose sandbox
  did not hold.

  Missing `codex` or `python3` exits 2. The scripts refuse rather than degrade,
  because a delegation path that silently becomes something weaker is worse
  than one that stops.

- **`tests/regression/cases/50_codex_delegation.sh`** -- 23 assertions driving
  `delegate.sh` against a *fake* `codex` on PATH, so every branch is covered
  deterministically and without consuming real quota: refusal when `codex` is
  absent, success despite an advisory `error` item, a non-zero inner command
  counted rather than hidden, a non-zero Codex exit propagated, and a write
  under `read-only` producing exit 3 with no success report. It also asserts
  that `--sandbox read-only` and `--output-schema` are actually on the command
  line, rather than trusting the script's own description of itself. It also
  asserts the scripts reach a project scaffolded with no pack flags at all.



- **Skill evals: 27 scenarios across all 9 skills, plus a contract check that
  runs in CI.** The official Agent Skills guidance says to write evaluations
  *before* writing extensive documentation, and the reason holds here: writing
  an eval forces you to name the observable difference a skill is supposed to
  make. Until PR #8 the skills had none, so nothing distinguished a skill that
  changed agent behavior from one that read well.

  Evals live at `tests/evals/<skill>/NN-<slug>.md` -- at the repository root,
  not under `template/`. They are a tool for the person *writing* a skill, not
  for an agent working in a generated project, so shipping them would add
  weight without adding capability. `40_skill_contract.sh` asserts they never
  leak into a generated project.

  Each eval names four things: the scenario, the expected behavior stated in
  **observable** terms, the **failing behavior** it is designed to catch, and
  whether judging it is mechanical or human. The third field is the one that
  makes the format work, and it carries a hard rule:

  > An eval that passes without the skill loaded measures nothing.

  So the failing behavior has to be a mistake a competent agent would
  plausibly make by default -- "merges once CI is green", "writes a design
  decision into `current-state.md`", "trusts a delegated agent's self-reported
  success over its exit code". An eval whose failure mode is obviously absurd
  always passes, and is decoration.

- **`tests/regression/cases/40_skill_contract.sh`** -- the mechanically
  checkable half. Per skill: frontmatter `name` matches `^[a-z0-9-]{1,64}$`
  and equals the directory name, `description` is present and within the size
  limit, `SKILL.md` is under 500 lines, and at least 3 well-formed evals
  exist. Repo-wide: no orphan eval directory, and every `` `AGENTS.md` §N ``
  reference from a skill resolves to a real section.

  That last check exists because the failure already happened. Renumbering
  AGENTS.md sections in this same release left two of three skill
  cross-references pointing at the wrong section; both were found by reading
  every reference by hand. This case makes that unnecessary.

  The case was mutation-tested rather than assumed to work: deleting an eval,
  emptying a required section, breaking a section reference, renaming a
  frontmatter `name`, and adding a skill with no evals each produce exit 1
  with a specific message, and the baseline returns to 0 afterward.

  **What it does not check is whether a skill works.** A green run means the
  evals exist and are well-formed. Behavioral evaluation needs an LLM, is
  nondeterministic, and is judged by hand -- the two are kept separate on
  purpose (`AGENTS.md` §3).

  One pre-existing problem surfaced and is reported rather than papered over:
  `template/skills/evidence-first-repro/SKILL.md:157` refers to a `§11` that
  does not exist in that file. It is emitted as a `WARN` and does not fail the
  case, because the correct target is unknown and guessing at it would be
  worse than leaving it visible.

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
