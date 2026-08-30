#!/usr/bin/env bash
# shellcheck disable=SC2034
# These variables are read by scripts/setup/scaffold.sh after it `source`s
# this manifest -- shellcheck can't see that cross-file usage.

PACK_NAME="codex"
PACK_VERSION="0.1.0"
PACK_DESCRIPTION="Mechanical layer for read-only Codex delegation"

PACK_MERGE_DIR="merge"
PACK_APPEND_DIR="append"
