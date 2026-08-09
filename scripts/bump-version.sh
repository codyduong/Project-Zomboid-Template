#!/usr/bin/env bash
# Set the mod's version (modversion) in every mod.info so all copies (41/42/...) never
# drift. This is the mod's OWN semver (e.g. 1.3.14) and must equal the release git tag
# (v1.3.14) — tooling/scripts/package.* enforce that. It is NOT the targeted PZ build (e.g.
# "B42.15"); that marker lives in 42/mod.info `name=` and workshop/workshop.vdf and is
# changed only when retargeting a new game build — see docs/UPDATING-PZ.md.
#
# Usage: mise run bump 1.3.14   (or: bash tooling/scripts/bump-version.sh 1.3.14)

set -e
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"
MOD_NAME="$(pz_mod_name)"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "ERROR: version argument required, e.g. 1.3.14" >&2
  exit 1
fi
# Strip a leading v/V (v2.0.0-rc.1 -> 2.0.0-rc.1) to store the bare semver.
VER="${VERSION#v}"
VER="${VER#V}"

# Official SemVer 2.0.0 grammar (https://semver.org): X.Y.Z with optional -prerelease and
# +build metadata. Accepts 1.3.14, 2.0.0-rc.1, 1.0.0-alpha.1+build.7, etc.
SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
if ! [[ "$VER" =~ $SEMVER_RE ]]; then
  echo "ERROR: version must be valid semver, e.g. X.Y.Z or X.Y.Z-rc.1 (got '$VERSION')." >&2
  exit 1
fi

found=0
while IFS= read -r info; do
  found=1
  if ! grep -q '^modversion=' "$info"; then
    echo "ERROR: no 'modversion=' line in $info" >&2
    exit 1
  fi
  # -i.bak/rm is the portable form across GNU sed (Linux) and BSD sed (macOS) -i syntax.
  sed -i.bak "s/^modversion=.*/modversion=$VER/" "$info"
  rm -f "$info.bak"
  echo "  set modversion=$VER in $info"
done < <(find "./Contents/mods/$MOD_NAME" -name "mod.info")

if [ "$found" -eq 0 ]; then
  echo "ERROR: no mod.info files found under Contents/mods/$MOD_NAME" >&2
  exit 1
fi

echo "Version set to $VER. Next: commit, tag v$VER, then 'mise run package v$VER'."
