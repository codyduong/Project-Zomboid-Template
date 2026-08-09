#!/usr/bin/env bash
# Ephemeral local dedicated server for MP testing — keeps your real game install and
# ~/Zomboid completely untouched:
#   - the PZ Dedicated Server (Steam app 380870, anonymous download) lives in .tools/pzserver
#   - ALL server state (configs, world, db, mods) lives in the git-ignored .testhost/ via
#     -cachedir; seed configs come from the source-controlled testhost/ dir
#   - first boot creates the admin account from -adminusername/-adminpassword
# Blow the world away and start fresh: --reset. See docs/TESTING.md.
#
# Usage: mise run testhost [--reset]
#    or: bash tooling/scripts/testhost.sh [--reset] [--admin-password pw] [--branch unstable]
#
# Unlike testhost.ps1 (which reimplements the Windows StartServer64.bat's java invocation
# by hand, because THAT .bat only forwards two positional args), this launches the Linux
# distribution's own start-server.sh with our flags -- it's a plain bash script that
# forwards all args, so there's no need to duplicate PZ's own classpath/native-lib wiring
# here (which would just be another thing to keep in sync with Valve's installer).

set -e
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"

RESET=0
ADMIN_PASSWORD="pztest"
BRANCH="unstable"
SERVER_DIR=".tools/pzserver"
CACHE_DIR=".testhost"

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --admin-password) ADMIN_PASSWORD="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --server-dir) SERVER_DIR="$2"; shift 2 ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# --- Install the dedicated server (one-time, ~4 GB, anonymous — no Steam Guard) ---------
LAUNCHER="$SERVER_DIR/start-server.sh"
if [ ! -f "$LAUNCHER" ]; then
  if ! command -v steamcmd >/dev/null 2>&1; then
    echo "ERROR: steamcmd not found on PATH." >&2
    exit 127
  fi
  abs_server_dir="$(pwd)/$SERVER_DIR"
  echo "Installing PZ Dedicated Server (app 380870, branch '$BRANCH') -> $abs_server_dir"
  echo "First run downloads ~4 GB."
  steamcmd +force_install_dir "$abs_server_dir" +login anonymous +app_update 380870 -beta "$BRANCH" validate +quit
  if [ ! -f "$LAUNCHER" ]; then
    echo "ERROR: steamcmd install failed, or this branch doesn't ship start-server.sh. List branches with:" >&2
    echo "       steamcmd +login anonymous +app_info_print 380870 +quit" >&2
    exit 1
  fi
fi
chmod +x "$LAUNCHER"

# --- Provision the ephemeral cachedir ----------------------------------------------------
if [ "$RESET" -eq 1 ] && [ -d "$CACHE_DIR" ]; then
  echo "Resetting testhost world: removing $CACHE_DIR"
  rm -rf "$CACHE_DIR"
fi
mkdir -p "$CACHE_DIR/Server"
# Seed configs only when missing so a running world's tweaks survive restarts;
# --reset is the way back to the canonical repo presets.
for f in servertest.ini servertest_SandboxVars.lua; do
  dst="$CACHE_DIR/Server/$f"
  [ -f "$dst" ] || cp "testhost/$f" "$dst"
done

# --- Deploy the mod into the testhost ----------------------------------------------------
bash "$(dirname "${BASH_SOURCE[0]}")/deploy-local.sh" server "$CACHE_DIR"

# --- Launch (foreground; the server console stays interactive) ---------------------------
abs_cache_dir="$(cd "$CACHE_DIR" && pwd)"
echo "Starting dedicated server (cachedir: $abs_cache_dir)"
echo "Connect from a normal game client: Join -> 127.0.0.1:16261, account 'admin' / '$ADMIN_PASSWORD'"
(
  cd "$SERVER_DIR"
  ./start-server.sh \
    -statistic 0 \
    -cachedir="$abs_cache_dir" \
    -adminusername admin \
    -adminpassword "$ADMIN_PASSWORD"
)
