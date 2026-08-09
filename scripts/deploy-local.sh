#!/usr/bin/env bash
# Package the mod, then sync it where the game loads it for local testing. The TARGET is
# required so a deploy never silently touches a location you didn't intend:
#   client — ~/Zomboid/Workshop/<mod>   (the "workshop (dev)" dir the CLIENT loads from;
#            Steam-mode only, so a dedicated server never sees it)
#   server — <cache-dir>/mods/<mod>     (the local-mods dir a dedicated server scans;
#            defaults to the ephemeral .testhost cachedir, NOT your real ~/Zomboid)
#   all    — both of the above
# See docs/TESTING.md.
#
# Usage: mise run deploy <client|server|all>
#    or: bash tooling/scripts/deploy-local.sh <client|server|all> [server-cache-dir]
#          (client dir override: $ZOMBOID_DIR)

set -e
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"
MOD_NAME="$(pz_mod_name)"

TARGET="${1:-}"
ZOMBOID_DIR="${ZOMBOID_DIR:-$HOME/Zomboid}"
SERVER_CACHE_DIR="${2:-.testhost}"

case "$TARGET" in
  client|server|all) ;;
  *)
    echo "ERROR: a target (client|server|all) is required." >&2
    exit 2
    ;;
esac

# Derive the current version from 42/mod.info so packaging validation passes trivially.
MOD_INFO="Contents/mods/$MOD_NAME/42/mod.info"
VER="$(grep '^modversion=' "$MOD_INFO" | head -n1 | cut -d= -f2 | tr -d '\r' | xargs)"
echo "Deploying $MOD_NAME v$VER ($TARGET)"

# Build (validates + assembles dist/<ModName>).
bash "$(dirname "${BASH_SOURCE[0]}")/package.sh" "v$VER"

if [ "$TARGET" = "client" ] || [ "$TARGET" = "all" ]; then
  if [ ! -d "$ZOMBOID_DIR" ]; then
    echo "ERROR: Zomboid dir not found: $ZOMBOID_DIR (set \$ZOMBOID_DIR)." >&2
    exit 1
  fi
  CLIENT_TARGET="$ZOMBOID_DIR/Workshop/$MOD_NAME"
  rm -rf "$CLIENT_TARGET"
  mkdir -p "$(dirname "$CLIENT_TARGET")"
  cp -r "./dist/$MOD_NAME" "$CLIENT_TARGET"
  echo "Synced (client, Workshop dev) -> $CLIENT_TARGET"
fi

if [ "$TARGET" = "server" ] || [ "$TARGET" = "all" ]; then
  SERVER_TARGET="$SERVER_CACHE_DIR/mods/$MOD_NAME"
  rm -rf "$SERVER_TARGET"
  mkdir -p "$(dirname "$SERVER_TARGET")"
  cp -r "./dist/$MOD_NAME/Contents/mods/$MOD_NAME" "$SERVER_TARGET"
  echo "Synced (dedicated server) -> $SERVER_TARGET"
fi

if [ "$TARGET" = "client" ] || [ "$TARGET" = "all" ]; then
  echo "In-game: enable the mod under Workshop (dev) mods, then load your debug scenario."
fi
