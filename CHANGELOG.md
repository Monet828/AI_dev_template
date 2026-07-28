# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] -- hardening pass (targeting 0.2.0)

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
