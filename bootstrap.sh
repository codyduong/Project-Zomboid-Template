#!/usr/bin/env bash
# One-time bootstrap for a mod repo created from this template ("Use this template" on
# GitHub, or a plain clone). Deliberately NOT under scripts/ -- that directory is the
# shared-scripts payload that gets replaced by the tooling/ submodule (see step 2 below),
# and this file has nothing to do once it's run. Mirrors bootstrap.ps1 -- keep in sync.
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
# Usage: bash bootstrap.sh YourModName [template-ref]
# Run this from the repo root, BEFORE adding tooling/ as a submodule.

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

MOD_NAME="${1:-}"
# Pin the generated CI callers to this ref of Project-Zomboid-Template. Defaults to "main";
# pass a tag (e.g. "v1.0.0") once the template has releases, for reproducible CI.
TEMPLATE_REF="${2:-main}"

if [ -z "$MOD_NAME" ]; then
  echo "Usage: bash bootstrap.sh YourModName [template-ref]" >&2
  exit 1
fi
if ! [[ "$MOD_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "ERROR: ModName should be a single PascalCase word (letters/digits, starts with a letter) -- it becomes a folder name and a PZ mod id." >&2
  exit 1
fi
if [ ! -d "templates" ]; then
  echo "ERROR: templates/ not found. Run this from a fresh checkout of the template, before it's been bootstrapped." >&2
  exit 1
fi

echo "Bootstrapping mod repo for '$MOD_NAME'..."

# --- 1. Stamp __MOD_NAME__ and promote templates/ to the repo root ----------------------
mv "templates/Contents/mods/__MOD_NAME__" "templates/Contents/mods/$MOD_NAME"

while IFS= read -r -d '' f; do
  if grep -q '__MOD_NAME__' "$f" 2>/dev/null; then
    sed -i.bak "s/__MOD_NAME__/$MOD_NAME/g" "$f"
    rm -f "$f.bak"
  fi
done < <(find "templates" -type f -print0)

# Strip the .tmpl suffix as files move to the repo root (keeps templates/ diffable against
# what actually gets scaffolded, without shipping ".tmpl" names into the real repo).
while IFS= read -r -d '' f; do
  mv "$f" "${f%.tmpl}"
done < <(find "templates" -type f -name '*.tmpl' -print0)

cp -r templates/. .
rm -rf templates

# --- 2. Drop the full scripts/ checkout -- tooling/ (the submodule) supplies it instead ---
rm -rf scripts

# --- 3. Thin CI callers instead of this repo's own reusable workflow definitions --------
mkdir -p .github/workflows
cat > .github/workflows/lint.yml <<EOF
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
    uses: codyduong/Project-Zomboid-Template/.github/workflows/lint.yml@$TEMPLATE_REF
EOF

cat > .github/workflows/release.yml <<EOF
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
    uses: codyduong/Project-Zomboid-Template/.github/workflows/release.yml@$TEMPLATE_REF
    with:
      tag_name: \${{ inputs.tag_name }}
      mod_name: $MOD_NAME
    secrets: inherit
EOF

# --- 4. Drop the template-authoring doc; it's about USING this template, not your mod ---
rm -f docs/USING-THIS-TEMPLATE.md

echo "Done. Next steps:"
echo "  1. git submodule add https://github.com/codyduong/Project-Zomboid-Template.git tooling"
echo "     (then: git -C tooling checkout <tag>, once one exists, instead of tracking main)"
echo "  2. Fill in workshop/item-ids.json and workshop/workshop.vdf once you've created the Workshop listing(s)."
echo "  3. mise install && mise run check"
echo "  See (this template's) docs/USING-THIS-TEMPLATE.md on GitHub for the rest."

# --- 5. Self-delete (and the sibling bootstrap.ps1, since only one OS's script ran) -------
rm -f "${BASH_SOURCE[0]}" "bootstrap.ps1"
