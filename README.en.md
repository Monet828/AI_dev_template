# AI_dev_template

*The primary README is [README.md](README.md) (Japanese). This is an English translation kept for reference; if the two ever disagree, README.md is authoritative.*

A lightweight project-generation tool for developing safely alongside AI coding agents (Claude Code, Codex, etc.).

## The problem AI-assisted development has

When you hand development over to an AI coding agent, this happens:

- **The agent loses context** — what you were aiming for and what you already decided disappears between sessions
- **The spec silently changes** — a "while I was at it" fix turns out to be an unagreed spec change
- **Scope creep sneaks in** — refactors and file generation you never asked for
- **Resuming after an interruption is hard** — how far you got and where you stopped gets buried in chat history
- **Verification results and decisions don't persist** — was "tests pass" actually true? Why was this design chosen? Nobody can tell later.

This template addresses this by externalizing project state into **Git-tracked files** instead of chat memory: current state (`memory/current-state.md`), decision records (`memory/decisions.md`), work boundaries (Goal / Scope / Out of Scope / Stop Conditions), and verification results (`verify.sh`'s actual run output plus `record-verification.sh`'s notes) all persist as files the next session, a different agent, or a human reviewer can read.

## 30-second Quick Start

```bash
git clone https://github.com/Monet828/AI_dev_template.git
cd AI_dev_template
./scripts/setup/new-project.sh /path/to/new-project full
cd /path/to/new-project
./scripts/setup/doctor.sh
```

If `doctor.sh` prints `passed: N, warnings: 0, errors: 0`, the project was generated correctly.

## What gets generated

`new-project.sh` (which calls `scaffold.sh` internally) merges the base template under `template/` with whichever `packs/` you selected, into the directory you specify. The generated project includes:

- `AGENTS.md` / `CLAUDE.md` — common rules for AI agents
- `app/` — the deployable application
- `docs/` — formal specs, ADRs, operational knowledge
- `memory/` — working memory (current-state / decisions / tasks / sessions)
- `scripts/` — bootstrap, doctor, verify, hooks, loop helpers
- `skills/` / `assets/` — reusable capabilities and assets
- `.ai-dev-template.yml` — records which `template_version` / `profile` / packs generated it
- `LICENSE` (MIT, placeholder copyright line)

**Not** included: this repo's own generator scripts (`scaffold.sh`/`new-project.sh`), `packs/` (pack-management code that doesn't work post-generation), this repo's own tests (`tests/regression/`), this repo's own README/CI, `.git`. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the reasoning behind the split.

## Profiles

Used as `new-project.sh <target_dir> <profile>`:

| profile | packs applied |
|---|---|
| `minimal` | none |
| `understand` | `understand-first` |
| `research` | `understand-first`, `evidence-first` |
| `strategy` | `evidence-first`, `problem-first` |
| `full` | `understand-first`, `evidence-first`, `problem-first` |
| `full-slides` | `understand-first`, `evidence-first`, `problem-first`, `slides` |

You can specify packs directly with `--packs pack1,pack2` instead of a profile (this takes precedence over the profile mapping).

## Packs

| pack | solves | adds |
|---|---|---|
| `understand-first` | understand existing code/specs before touching them | `memory/understanding-map.md`, `scripts/workflows/understand-first.sh` |
| `evidence-first` | build evidence before proposing/comparing | `memory/evidence-log.md`, `scripts/workflows/evidence-first.sh` |
| `problem-first` | define the problem first, then decompose | `memory/problem-map.md`, `docs/templates/PROBLEM-BRIEF.md`, `scripts/workflows/problem-framing.sh` |
| `slides` | add slide assets | `assets/slides/SLIDE-md/`, `assets/slides/SLIDE-PATTERN/` |

Each pack's real version lives in its `pack-manifest.sh` and is recorded into `.ai-dev-template.yml` at generation time.

## Safety & git workflow

- `scripts/hooks/pre-push` is an **opt-in pre-push hook** that detects and blocks direct pushes and force-pushes to protected branches (main/master/develop/integration/release, plus `origin`'s default branch). Installing it requires explicitly running `./scripts/hooks/install-hooks.sh` -- **nothing is installed by default**.
- This hook is **not a security boundary**. `ALLOW_PROTECTED_PUSH=1 git push ...` lets a human deliberately override it, `--no-verify` bypasses it too, and it never runs at all unless `install-hooks.sh` was run. An AI agent could just as easily set an environment-variable override itself. `scripts/hooks/{pre-task,post-task,stop,save-memory}.sh` are a separate thing entirely -- not git hooks, just manual checkpoint scripts for AI agents.
- The real protection boundary is GitHub branch protection / rulesets. Example (`gh` CLI, meant to be copy-pasted and run deliberately by you -- nothing in this repo runs it automatically):
  ```bash
  gh api repos/:owner/:repo/rulesets -X POST \
    -f name='protect-main' \
    -f target='branch' \
    -f enforcement='active' \
    -f 'conditions[ref_name][include][]=refs/heads/main' \
    -f 'rules[][type]=pull_request'
  ```
- Generation itself is transactional: `scaffold.sh` builds in a temporary directory and only moves it into place once every step succeeds. It never overwrites an existing (non-empty) directory.

## How to verify

Inside a generated project:

```bash
./scripts/loop/verify.sh
```

Detects `pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod` and runs only whatever is actually configured. Shell syntax checking always runs. Output is `[PASS]`/`[SKIP: reason]`/`[FAIL]`, and it exits non-zero if any configured check fails.

To log the result and your own notes into `memory/sessions/`:

```bash
./scripts/loop/record-verification.sh
```

To verify this repository itself (AI_dev_template):

```bash
find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -n 1 bash -n
shellcheck $(find . -type f -name '*.sh' -not -path './.git/*')
./tests/regression/run.sh
```

## Example

`examples/` has one small worked example, reproducible with the actual generation flow. It covers the problem framed, the profile/packs chosen, the key generated files, a sample session log, a sample decision record, `verify.sh`'s actual output, and an example of a different agent resuming after an interruption. See [`examples/README.md`](examples/README.md).

## Design philosophy

- Project state, spec, decisions, scope boundaries, and verification records are externalized to version-controlled files, not chat memory
- The base template is self-contained without any packs
- Specialized workflows are added as opt-in packs under `packs/`
- `docs/` holds formal specs; `memory/` holds working memory -- kept separate
- Generation is non-destructive and transactional

## Non-goals

- A large GUI
- Becoming a web service
- Publishing to npm/pip
- A complex plugin marketplace
- Direct AI model API integration
- Rewriting every script in a different language

## Constraints

- Shell scripts are expected to run on both macOS's stock `/bin/bash` (3.2, no bash 4+-only syntax) and Linux. CI checks both `ubuntu-latest` and `macos-latest`.
- `verify.sh`'s ecosystem detection is heuristic (e.g. detecting placeholder `package.json` scripts) and not perfect.
- Pack manifests are currently plain `source`d shell (see [`SECURITY.md`](SECURITY.md) for the reasoning and risk).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) -- read the "`template/` vs. repository root" section first.

## License

[MIT License](LICENSE). Generated projects also include a copy with a placeholder copyright line (`template/LICENSE`).
