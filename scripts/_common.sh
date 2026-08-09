#!/usr/bin/env bash
# Sourced by every script in this directory: . "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
#
# This scripts/ directory is designed to be mounted as a git submodule at <mod-repo>/tooling
# (see docs/USING-THIS-TEMPLATE.md), so it cannot hardcode a mod name or assume it lives one
# directory below the consuming repo's root. Both are resolved here instead. Mirrors
# _common.ps1 -- keep the two in sync.

# The consuming (super-project) repo root is two hops up from this file's location
# (<repo>/tooling/scripts/_common.sh -> tooling/scripts -> tooling -> <repo>). If you ever
# change the submodule's mount path away from "tooling/", update this.
pz_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "$script_dir/../.." && pwd)
}

# Every mod repo scaffolded from this template has exactly one folder under Contents/mods/
# -- derive the mod name from it instead of hardcoding it, so these scripts need zero
# per-repo edits.
pz_mod_name() {
  local name
  name="$(ls "Contents/mods" 2>/dev/null | head -n1)"
  if [ -z "$name" ]; then
    echo "ERROR: no folder found under Contents/mods/ (expected exactly one, the mod itself)." >&2
    exit 1
  fi
  echo "$name"
}
