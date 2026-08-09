#!/usr/bin/env pwsh
# One-time bootstrap for a mod repo created from this template ("Use this template" on
# GitHub, or a plain clone). Deliberately NOT under scripts/ -- that directory is the
# shared-scripts payload that gets replaced by the tooling/ submodule (see step 2 below),
# and this file has nothing to do once it's run.
#
# What it does:
#   1. Replaces the __MOD_NAME__ placeholder throughout templates/, then copies templates/
#      into the repo root and removes templates/ itself.
#   2. Removes the top-level scripts/ this repo shipped as a full checkout (you'll get
#      scripts back via the tooling/ submodule instead -- see the printed next steps).
#   3. Replaces .github/workflows/{lint,release}.yml (the reusable workflow_call definitions
#      meant to live in THIS template repo) with thin callers pointing back at it.
#   4. Removes docs/USING-THIS-TEMPLATE.md (about using this template, not about your mod).
#   5. Deletes itself.
#
# Usage: pwsh -NoProfile -File bootstrap.ps1 -ModName YourModName
# Run this from the repo root, BEFORE adding tooling/ as a submodule.

param(
  [Parameter(Mandatory = $true)]
  [string]$ModName,
  # Pin the generated CI callers to this ref of Project-Zomboid-Template. Defaults to
  # "main"; pass a tag (e.g. "v1.0.0") once the template has releases, for reproducible CI.
  [string]$TemplateRef = "main"
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if ($ModName -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
  Write-Host "ERROR: ModName should be a single PascalCase word (letters/digits, starts with a letter) -- it becomes a folder name and a PZ mod id." -ForegroundColor Red
  exit 1
}

if (-not (Test-Path "templates")) {
  Write-Host "ERROR: templates/ not found. Run this from a fresh checkout of the template, before it's been bootstrapped." -ForegroundColor Red
  exit 1
}

Write-Host "Bootstrapping mod repo for '$ModName'..." -ForegroundColor Cyan

# --- 1. Stamp __MOD_NAME__ and promote templates/ to the repo root ----------------------
# (Rename-Item's -NewName must be a leaf name, not a path, when renaming in place.)
Rename-Item -Path "templates/Contents/mods/__MOD_NAME__" -NewName $ModName

Get-ChildItem -Path "templates" -Recurse -File | ForEach-Object {
  $content = Get-Content -Raw -Path $_.FullName -ErrorAction SilentlyContinue
  if ($null -ne $content -and $content.Contains('__MOD_NAME__')) {
    Set-Content -Path $_.FullName -Value ($content -replace '__MOD_NAME__', $ModName) -NoNewline
  }
}

# Strip the .tmpl suffix as files move to the repo root (keeps templates/ diffable against
# what actually gets scaffolded, without shipping ".tmpl" names into the real repo).
Get-ChildItem -Path "templates" -Recurse -File -Filter "*.tmpl" | ForEach-Object {
  Rename-Item $_.FullName ($_.FullName -replace '\.tmpl$', '')
}

Copy-Item "templates/*" "." -Recurse -Force
Remove-Item "templates" -Recurse -Force

# --- 2. Drop the full scripts/ checkout -- tooling/ (the submodule) supplies it instead ---
if (Test-Path "scripts") { Remove-Item "scripts" -Recurse -Force }

# --- 3. Thin CI callers instead of this repo's own reusable workflow definitions --------
New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
@"
name: Validate Lua

on:
  push:
    paths:
      - '**.lua'
    branches:
      - master
  pull_request:
    paths:
      - '**.lua'
    branches:
      - master

jobs:
  call:
    uses: codyduong/Project-Zomboid-Template/.github/workflows/lint.yml@$TemplateRef
"@ | Set-Content ".github/workflows/lint.yml" -NoNewline

@"
name: Release Mod

on:
  workflow_dispatch:
    inputs:
      tag_name:
        description: 'Version Tag (e.g., v1.0.1)'
        required: true
        type: string

jobs:
  call:
    uses: codyduong/Project-Zomboid-Template/.github/workflows/release.yml@$TemplateRef
    with:
      tag_name: `${{ inputs.tag_name }}
      mod_name: $ModName
    secrets: inherit
"@ | Set-Content ".github/workflows/release.yml" -NoNewline

# --- 4. Drop the template-authoring doc; it's about USING this template, not your mod ---
Remove-Item "docs/USING-THIS-TEMPLATE.md" -Force -ErrorAction SilentlyContinue

Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host "  1. git submodule add https://github.com/codyduong/Project-Zomboid-Template.git tooling" -ForegroundColor Green
Write-Host "     (then: git -C tooling checkout <tag>, once one exists, instead of tracking main)" -ForegroundColor Green
Write-Host "  2. Fill in workshop/item-ids.json and workshop/workshop.vdf once you've created the Workshop listing(s)." -ForegroundColor Green
Write-Host "  3. mise install && mise run check" -ForegroundColor Green
Write-Host "  See (this template's) docs/USING-THIS-TEMPLATE.md on GitHub for the rest." -ForegroundColor Green

# --- 5. Self-delete (and the sibling bootstrap.sh, since only one OS's script ran) --------
Remove-Item $PSCommandPath -Force
Remove-Item "bootstrap.sh" -Force -ErrorAction SilentlyContinue
