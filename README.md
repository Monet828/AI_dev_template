# AI_dev_template

A lightweight scaffolding tool for projects where AI coding agents (Claude
Code, Codex) and humans work from the same files.

## The problem

Left to a chat session, an AI coding agent tends to:

- **lose context across sessions** -- what the goal was, what got decided
- **quietly change scope** -- a "while I'm at it" fix that was never agreed to
- **wander outside the ask** -- unrequested refactors, extra files
- **become hard to resume** -- where it stopped is buried in chat history
- **leave no record of verification or decisions** -- "tests pass" said by
  whom, checked how; a design choice made for what reason

This template externalizes that state into git-tracked files instead of chat
memory: current state (`memory/current-state.md`), decisions
(`memory/decisions.md`), work boundaries (Goal / Scope / Out of Scope / Stop
Conditions), and verification results (`verify.sh`'s output, recorded by
`record-verification.sh`). All of it is readable by the next session, a
different agent, or a human reviewer.

## Quick start

```bash
git clone https://github.com/Monet828/AI_dev_template.git
cd AI_dev_template
./scripts/setup/new-project.sh /path/to/new-project full
cd /path/to/new-project
./scripts/setup/doctor.sh
```

`doctor.sh` printing `passed: N, warnings: 0, errors: 0` means the project
generated correctly.

## What gets generated

`new-project.sh` (which calls `scaffold.sh` internally) merges `template/`
with whichever `packs/` you select into a new directory. The result includes:

- `AGENTS.md` / `CLAUDE.md` -- rules every agent in the project follows
- `skills/` -- on-demand procedures (see below); not preloaded into context
- `scripts/codex/` -- Codex delegation and a claim-verification queue (see below)
- `app/` -- the application being built
- `docs/` -- specs, ADRs, playbooks
- `memory/` -- working memory (`current-state.md`, `decisions.md`, `tasks.md`, `sessions/`)
- `scripts/` -- bootstrap, doctor, verify, hooks, loop helpers
- `assets/` -- reusable, pack-provided assets
- `.ai-dev-template.yml` -- records which `template_version` / profile / packs generated this project
- `LICENSE` (MIT, with a placeholder copyright line)

**Not included**: this repo's own generator (`scaffold.sh`/`new-project.sh`),
`packs/` (pack machinery has no purpose once a project exists), this repo's
own tests (`tests/`), its README/CI, or `.git`. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for why the split is drawn there.

## Skills

`AGENTS.md` is injected into context on every turn, so its size is a
standing tax regardless of the task. Nine skills under `template/skills/`
carry the procedures that are only needed at specific moments -- only their
`name` and `description` sit in context until one is actually read.

| Skill | For |
|---|---|
| `session-bootstrap` | starting, scoping, and closing a work session; declaring Goal/Scope/Stop Conditions |
| `managing-memory` | deciding what goes in `memory/current-state.md` vs `decisions.md` vs `tasks.md`, and when to promote to `docs/` |
| `recording-decisions` | writing a design decision so it stays reusable (alternatives considered, revision conditions) |
| `reviewing-changes` | what to look for in a diff, and how to report it with evidence and a fix |
| `running-loops` | long or multi-session work: state on disk, retry budgets, a resumable handoff |
| `delegating-to-codex` | when delegating to Codex pays off (and the more common case where it doesn't), the task/report contract, and the discovery queue below |
| `code-review` | applying a repo's own `AGENTS.md` rules mechanically against a diff |
| `evidence-first-repro` | turning researched facts about a competitor's feature into a grounded reproduction spec |
| `saas-research-to-prototype` | compressing competitor research into screens, data model, and a minimal MVP |

Each skill has at least 3 evals under `tests/evals/<skill>/` -- scenarios
naming the expected behavior and, just as importantly, the plausible *wrong*
behavior a competent agent would default to without the skill. Evals are a
skill-authoring tool and never ship into a generated project;
`tests/regression/cases/40_skill_contract.sh` checks that every skill has
them, that frontmatter matches the Agent Skills spec, and that
`` `AGENTS.md` §N `` cross-references from skills still resolve.

## Codex delegation

Every generated project ships `scripts/codex/delegate.sh` and `review.sh`,
the mechanical half of `delegating-to-codex`'s report contract: `status`
comes from the process exit code, `files_modified` from a git diff before
and after, not from Codex's self-report. The sandbox is always read-only and
the scripts verify that invariant themselves.

Measured trade-off, so routing isn't guesswork: delegating costs **3.6x**
the tokens of doing the same work directly (it re-runs exploration commands
Claude wouldn't need to). It pays off when Claude's usage limit is the
binding constraint, when a second model's review is wanted
(`review.sh` wraps `codex exec review`), or for a long investigation run
alongside other work -- not "just in case."

### Discovery queue

`discover.sh` and `dispatch.sh` split *when to look* from *when to spend
quota*. `discover.sh` scans for an `<!-- codex:verify -->` marker followed
by a documented claim (a README assertion, a spec's `[x]` line, an
`AGENTS.md` invariant) and appends new ones to `memory/codex-queue.jsonl`.
**It never calls Codex** -- only reads and appends -- so it's safe to run on
any schedule, including cron or launchd. `dispatch.sh --next` is the only
thing that spends quota, and it only runs when a human runs it: it hands one
queued claim to `delegate.sh` as a fact-check ("does this claim hold against
the code"), and folds the confirmed/falsified/uncertain verdict back into
the queue. A `falsified` result is a successful check, not a failure --
that's how the first real run of this found an actual bug (a secret-file
exclusion pattern that didn't match its own README description).

`docs/playbooks/codex-discovery-patrol.md` has launchd/cron templates for
`discover.sh`; deliberately not for `dispatch.sh`.

## Profiles

`new-project.sh <target_dir> <profile>`:

| Profile | Packs applied |
|---|---|
| `minimal` | none |
| `understand` | `understand-first` |
| `research` | `understand-first`, `evidence-first` |
| `strategy` | `evidence-first`, `problem-first` |
| `full` | `understand-first`, `evidence-first`, `problem-first` |
| `full-slides` | `understand-first`, `evidence-first`, `problem-first`, `slides` |

`--packs pack1,pack2` selects packs directly instead of a profile.

## Packs

| Pack | Solves | Adds |
|---|---|---|
| `understand-first` | understand existing code/specs before touching them | `memory/understanding-map.md`, `scripts/workflows/understand-first.sh` |
| `evidence-first` | ground proposals and comparisons in evidence before opinions | `memory/evidence-log.md`, `docs/templates/evidence-card.md`, `scripts/workflows/evidence-first.sh` |
| `problem-first` | define and decompose the problem before building | `memory/problem-map.md`, `docs/templates/PROBLEM-BRIEF.md`, `scripts/workflows/problem-framing.sh` |
| `slides` | add slide-deck assets | `assets/slides/SLIDE-md/`, `assets/slides/SLIDE-PATTERN/` |

Each pack's real version lives in its `pack-manifest.sh` and gets recorded
into the generated project's `.ai-dev-template.yml`.

## Safety & git workflow

- `scripts/hooks/pre-push` is an **opt-in** pre-push hook that blocks direct
  pushes and force-pushes to protected branches (main/master/develop/
  integration/release, plus `origin`'s default branch). Installing it
  requires explicitly running `./scripts/hooks/install-hooks.sh` --
  **nothing is installed by default**.
- This hook is **not a security boundary**. A human can override it with
  `ALLOW_PROTECTED_PUSH=1 git push ...`, bypass it with `--no-verify`, or
  simply never install it -- and an agent could set that same environment
  variable itself. `scripts/hooks/{pre-task,post-task,stop,save-memory}.sh`
  are a different thing entirely: not git hooks, but manual checkpoint
  scripts for an AI agent to run.
- The real protection boundary is GitHub's branch protection / rulesets, e.g.
  (`gh` CLI, meant to be copied and run by a human -- nothing in this repo
  runs it automatically):
  ```bash
  gh api repos/:owner/:repo/rulesets -X POST \
    -f name='protect-main' \
    -f target='branch' \
    -f enforcement='active' \
    -f 'conditions[ref_name][include][]=refs/heads/main' \
    -f 'rules[][type]=pull_request'
  ```
- Generation itself is transactional: `scaffold.sh` builds in a temp
  directory and only moves it into place once every step succeeds. It never
  overwrites an existing, non-empty target directory.

## How to verify

Inside a generated project:

```bash
./scripts/loop/verify.sh
```

This detects `pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod` and runs
only the test/lint/build steps that are actually configured; shell syntax
checks always run. Output is `[PASS]`/`[SKIP: reason]`/`[FAIL]`, and a
configured-but-failing step exits non-zero.

To record the result and your own notes in `memory/sessions/`:

```bash
./scripts/loop/record-verification.sh
```

This repo's own checks:

```bash
find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -n 1 bash -n
shellcheck $(find . -type f -name '*.sh' -not -path './.git/*')
./tests/regression/run.sh
```

## Example

`examples/` has one small, reproducible example: the problem framing, the
profile/packs chosen, the key generated files, a sample session log and
decision record, a `verify.sh` run, and a different agent resuming after an
interruption. See [`examples/README.md`](examples/README.md).

## Design philosophy

- Project state, spec, decisions, scope boundaries, and verification results
  live in version-controlled files, not chat memory
- The base template is self-contained with no packs installed
- Specialized workflows are opt-in packs under `packs/`
- `docs/` is the spec of record; `memory/` is working memory -- kept separate
- Procedures that aren't needed every turn live in `skills/`, loaded on
  demand, not in `AGENTS.md`
- Generation is non-destructive and transactional

## Non-goals

- A large GUI
- Becoming a hosted web service
- Publishing to npm/PyPI
- A plugin marketplace
- Direct integration with an AI model API
- Rewriting every script in a different language

## Constraints

- Shell scripts target macOS's stock `/bin/bash` (3.2, no bash-4+-only
  syntax) and Linux alike. CI runs both `ubuntu-latest` and `macos-latest`.
- `verify.sh`'s ecosystem detection is heuristic (e.g. deciding whether a
  `package.json` script is a real check or a placeholder) and not perfect.
- Pack manifests are plain shell, `source`d rather than parsed (see
  [`SECURITY.md`](SECURITY.md)).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) -- read "Repository layout" first,
and "Adding or changing a skill" if that's what you're doing.

## License

[MIT License](LICENSE). Generated projects include the same license with a
placeholder copyright line (`template/LICENSE`).
