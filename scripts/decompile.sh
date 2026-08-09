#!/usr/bin/env bash
# Decompile the installed Project Zomboid into ./.decompiled/<version>/ for client/server
# analysis, alongside a same-build snapshot of the vanilla Lua callers.
# Uses Zomboid Decompiler (demiurgeQuantified, Vineflower-based, supports 42.13+) — the
# release zip ships both a Windows launcher (bin/ZomboidDecompiler.bat) and a Linux/macOS one
# (bin/ZomboidDecompiler, this script's target).
# Preferred: `mise run decompile 42.20.2`
#    Direct: `bash tooling/scripts/decompile.sh 42.20.2 [game-path]`
#
# Why: Java type stubs tell you a method's SIGNATURE, but not whether it is
# client-authoritative, server-authoritative, or synced. Reading the decompiled source is
# how you verify what an API ACTUALLY does before overriding it. See CLAUDE.md ("golden rule").
#
# Each build's output lands in its own folder (.decompiled/<version>/source,
# .decompiled/<version>/media/lua) so the old and new builds sit side by side for diffing —
# see docs/UPDATING-PZ.md.
#
# Requires: curl (or wget), unzip.

set -e
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"

# PZ build string identifying the output folder, e.g. "42.20.2" (Major.Minor.Patch — patches
# can change Java behavior too, so don't truncate). Required — auto-detection from
# version.txt is unreliable (only rewrites on launch; see docs/UPDATING-PZ.md #0).
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "ERROR: a PZ build version is required, e.g. 42.20.2" >&2
  exit 1
fi
GAME_PATH="${2:-${PZ_HOME:-}}"
DECOMPILER_VERSION="${DECOMPILER_VERSION:-v0.3.1}"
OUT_DIR=".decompiled"
TOOLS_DIR=".tools"

# --- Resolve the game path --------------------------------------------------------------
if [ -z "$GAME_PATH" ]; then
  for candidate in \
    "$HOME/.steam/steam/steamapps/common/ProjectZomboid" \
    "$HOME/.local/share/Steam/steamapps/common/ProjectZomboid" \
    "$HOME/Library/Application Support/Steam/steamapps/common/ProjectZomboid"
  do
    if [ -f "$candidate/projectzomboid.jar" ]; then GAME_PATH="$candidate"; break; fi
  done
fi
if [ -z "$GAME_PATH" ] || [ ! -f "$GAME_PATH/projectzomboid.jar" ]; then
  echo "ERROR: Could not find ProjectZomboid install (projectzomboid.jar)." >&2
  echo "       Pass it as the 2nd argument or set \$PZ_HOME." >&2
  exit 1
fi
GAME_PATH="$(cd "$GAME_PATH" && pwd)"
echo "Game: $GAME_PATH"

# --- Ensure the decompiler is present ---------------------------------------------------
TOOL_ROOT="$TOOLS_DIR/ZomboidDecompiler"
LAUNCHER="$TOOL_ROOT/bin/ZomboidDecompiler"
if [ ! -f "$LAUNCHER" ]; then
  echo "Downloading Zomboid Decompiler $DECOMPILER_VERSION..."
  mkdir -p "$TOOLS_DIR"
  ZIP="$TOOLS_DIR/ZomboidDecompiler.zip"
  URL="https://github.com/demiurgeQuantified/ZomboidDecompiler/releases/download/$DECOMPILER_VERSION/ZomboidDecompiler.zip"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$ZIP"
  else
    wget -q "$URL" -O "$ZIP"
  fi
  rm -rf "$TOOL_ROOT"
  mkdir -p "$TOOL_ROOT"
  unzip -q "$ZIP" -d "$TOOL_ROOT"
  rm -f "$ZIP"
  # The zip may nest everything one level deep; normalize so bin/ is directly under $TOOL_ROOT.
  if [ ! -f "$LAUNCHER" ]; then
    nested="$(find "$TOOL_ROOT" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/bin/ZomboidDecompiler' \; -print -quit)"
    if [ -n "$nested" ]; then
      mv "$nested"/* "$nested"/.[!.]* "$TOOL_ROOT" 2>/dev/null || true
    fi
  fi
fi
if [ ! -f "$LAUNCHER" ]; then
  echo "ERROR: bin/ZomboidDecompiler not found after extraction ($TOOL_ROOT)." >&2
  echo "       Download manually from https://github.com/demiurgeQuantified/ZomboidDecompiler/releases" >&2
  exit 1
fi
chmod +x "$LAUNCHER"

# --- Run it -----------------------------------------------------------------------------
# The decompiler needs Java 17+. `mise run decompile` puts the pinned Temurin 17 on PATH.
# If no java is on PATH (running this script outside mise), fall back to the game's bundled
# JRE (jre64, also Java 17).
if ! command -v java >/dev/null 2>&1; then
  JRE_BIN="$GAME_PATH/jre64/bin"
  [ -d "$JRE_BIN" ] && PATH="$JRE_BIN:$PATH"
fi

echo "Decompiling..."
(cd "$TOOL_ROOT" && ./bin/ZomboidDecompiler "$GAME_PATH")

# --- Relocate output into .decompiled/<version>/source ---------------------------------
# Portable "newest dir named output" (avoids GNU-only `find -printf`, which BSD/macOS find
# lacks): try GNU `stat -c`, fall back to BSD `stat -f`.
newest_output_dir() {
  local best="" best_ts=-1 d ts
  while IFS= read -r d; do
    ts=$(stat -c '%Y' "$d" 2>/dev/null || stat -f '%m' "$d" 2>/dev/null)
    if [ -n "$ts" ] && [ "$ts" -gt "$best_ts" ]; then best_ts="$ts"; best="$d"; fi
  done < <(find "$TOOL_ROOT" -type d -name output)
  printf '%s' "$best"
}
produced="$(newest_output_dir)"
version_out="$(pwd)/$OUT_DIR/$VERSION"
source_out="$version_out/source"
if [ -n "$produced" ]; then
  rm -rf "$source_out"
  mkdir -p "$source_out"
  cp -r "$produced"/. "$source_out"
  echo "Decompiled source -> $OUT_DIR/$VERSION/source/"
else
  echo "Decompiler finished, but no 'output' folder was found under $TOOL_ROOT."
  echo "Look inside $TOOL_ROOT for the results and copy them into $source_out manually."
fi

# --- Snapshot vanilla game resources from the SAME install, alongside the Java -----------
# Mirrors the game's own media/ layout under the version folder (media/lua for now; other
# media/ subfolders can be added the same way later) so two builds sit side by side for a
# straight `git diff --no-index`.
media_out="$version_out/media"
rm -rf "$media_out"
mkdir -p "$media_out"
cp -r "$GAME_PATH/media/lua" "$media_out/"
echo "Vanilla Lua snapshot -> $OUT_DIR/$VERSION/media/lua/"
