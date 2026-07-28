# Security Policy

## Reporting a vulnerability

This is a small personal project. If you find a security issue, please open
a [private security advisory on GitHub](../../security/advisories/new)
rather than a public issue, so it can be assessed before details are public.

## Known, accepted risks in this design

### Pack manifests are `source`d shell, not parsed data

`packs/*/pack-manifest.sh` is executed via `source` inside
`scripts/setup/scaffold.sh`, not parsed as inert data. In principle this
means a pack manifest can run arbitrary shell code with the same privileges
as whoever runs `scaffold.sh`/`new-project.sh`.

In practice, today's risk is low: all four packs shipped in this repo are
authored by the maintainer, contain only plain variable assignments, and no
third-party pack distribution mechanism exists. This was evaluated during
the hardening pass that added this document and deliberately **not**
migrated to a declarative format (TOML/JSON/YAML) this round, to avoid
adding a new parsing dependency for a four-pack, single-maintainer repo.

If this project ever accepts packs from anyone other than the maintainer,
this should be revisited before doing so -- do not `source` untrusted pack
manifests. A safe migration path: replace `pack-manifest.sh` with a plain
`key: value` text file parsed line-by-line in pure Bash (no `source`, no new
dependency), which is straightforward given the manifest's current shape
(five flat scalar fields).

### `verify.sh` runs project-configured commands

The verification runner (`scripts/loop/verify.sh` inside a generated
project) executes whatever test/lint/build commands it detects as
configured (`npm run test`, `pytest`, `cargo test`, etc.). It does not
sandbox these -- it assumes you already trust the code in the project
you're verifying, which is true by construction (it's your own project).

### The pre-push hook is opt-in and is not a security boundary

`scripts/hooks/pre-push` blocks direct/force pushes to protected branches,
but it is never installed automatically -- it only takes effect after
someone explicitly runs `./scripts/hooks/install-hooks.sh`. Even installed,
it's bypassable (`ALLOW_PROTECTED_PUSH=1`, `--no-verify`, or simply never
installing it in the first place). Do not treat it as a security boundary;
see `template/README.md`'s "Safety & git workflow" section for the actual
protection boundary (GitHub branch protection / rulesets).
