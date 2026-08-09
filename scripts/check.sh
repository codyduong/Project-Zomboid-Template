#!/usr/bin/env bash
# Lint + type-check the mod's Lua. Mirrors .github/workflows/lint.yml.
# Preferred: `mise run check`   Direct: `bash tooling/scripts/check.sh`

set -u
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"

require_tool() {
  local name="$1" hint="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "ERROR: '$name' not found. $hint" >&2
    exit 127
  fi
}

require_tool luafmt "Run 'mise install' (or: cargo install emmylua_formatter --version 0.24.0)."
require_tool emmylua_check "Run 'mise install' (or: cargo install emmylua_check --version 0.24.0)."

failed=0

echo "==> luafmt . --check"
luafmt . --check || failed=1

echo "==> emmylua_check . -c .emmyrc.json"
emmylua_check . -c .emmyrc.json || failed=1

if [ "$failed" -ne 0 ]; then
  echo "Lua checks FAILED." >&2
  exit 1
fi
echo "All Lua checks passed."
