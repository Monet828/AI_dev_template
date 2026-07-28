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

### No git hook is installed by this template

Nothing in this repository installs a git hook of any kind (see
`template/README.md`'s "Safety & git workflow" section). There is no
pre-push enforcement to bypass, because none exists. Do not rely on a local
hook as a security boundary even if you add one later -- see that section
for why.
