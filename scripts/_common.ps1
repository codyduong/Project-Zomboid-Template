# Dot-sourced by every script in this directory: . (Join-Path $PSScriptRoot "_common.ps1")
#
# This scripts/ directory is designed to be mounted as a git submodule at <mod-repo>/tooling
# (see docs/USING-THIS-TEMPLATE.md), so it cannot hardcode a mod name or assume it lives one
# directory below the consuming repo's root. Both are resolved here instead.

# The consuming (super-project) repo root is two hops up from this file's location
# (<repo>/tooling/scripts/_common.ps1 -> tooling/scripts -> tooling -> <repo>). If you ever
# change the submodule's mount path away from "tooling/", update this.
function Get-PZRepoRoot {
  Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

# Every mod repo scaffolded from this template has exactly one folder under Contents/mods/
# -- derive the mod name from it instead of hardcoding it, so these scripts need zero
# per-repo edits.
function Get-PZModName {
  $dir = Get-ChildItem "Contents/mods" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $dir) {
    Write-Host "ERROR: no folder found under Contents/mods/ (expected exactly one, the mod itself)." -ForegroundColor Red
    exit 1
  }
  $dir.Name
}
