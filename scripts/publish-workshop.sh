#!/usr/bin/env bash
# Publish the packaged mod to the Steam Workshop via steamcmd (updates the existing item).
#
# SOURCE OF TRUTH for the listing is workshop/workshop.vdf — a steamcmd KeyValues file
# stored verbatim. This script only substitutes the dynamic fields ({{PUBLISHEDFILEID}},
# {{CONTENTFOLDER}}, {{PREVIEWFILE}}, {{CHANGENOTE}}, {{VISIBILITY}}); title/description/tags
# are edited directly in that file. Visibility is per-target: prod is public, test is
# unlisted. See docs/RELEASING.md.
#
# Workshop item ids are per-mod (and public, so committing them is fine) and live in
# workshop/item-ids.json (read via jq), NOT in this shared script — this file is shared
# across every mod repo via the tooling/ submodule.
#
# The publish TARGET (test|prod) is REQUIRED (unless --dry-run) so we're always explicit
# about which Workshop item we touch — there is no default and no env fallback.
#
# Usage: bash tooling/scripts/publish-workshop.sh <test|prod> ["changenote"] [--dry-run]
#    or: bash tooling/scripts/publish-workshop.sh <test|prod> --changenote-file notes.bbcode
#    or: mise run publish test "Fixed multi-barrel draw on 42.19"   (verify, then: ... prod ...)
#   --changenote-file   read the changenote from a file (bbcode, may be multiline); mutually
#                       exclusive with the inline changenote argument
#   --dry-run           build + print the VDF, don't upload (defaults target to test)
#
# Requires: steamcmd (unless --dry-run), jq (to read workshop/item-ids.json).

set -e
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(pz_repo_root)"
MOD_NAME="$(pz_mod_name)"
APP_ID="108600"

TARGET=""
CHANGENOTE=""
CHANGENOTE_FILE=""
STEAM_USER="${STEAM_USERNAME:-}"
DRY_RUN=0

# First two bare args are target/changenote (mirrors the .ps1's positional params); flags
# can appear anywhere after.
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --changenote-file) CHANGENOTE_FILE="$2"; shift 2 ;;
    --steam-user) STEAM_USER="$2"; shift 2 ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$1"
      elif [ -z "$CHANGENOTE" ]; then CHANGENOTE="$1"
      fi
      shift
      ;;
  esac
done
TARGET="$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')"

command -v jq >/dev/null 2>&1 || { echo "ERROR: 'jq' not found (required to read workshop/item-ids.json)." >&2; exit 127; }

ITEM_IDS_PATH="workshop/item-ids.json"
if [ ! -f "$ITEM_IDS_PATH" ]; then
  echo "ERROR: $ITEM_IDS_PATH not found. Create it with your Workshop item ids:" >&2
  echo '       { "test": "<id>", "prod": "<id>" }' >&2
  exit 1
fi

if [ -z "$TARGET" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    TARGET="test"
    echo "No target given; defaulting --dry-run to 'test'."
  else
    echo "ERROR: a target (test|prod) is required unless --dry-run." >&2
    echo "       Refusing to publish without an explicit target." >&2
    exit 2
  fi
fi

PUBLISHED_FILE_ID="$(jq -r --arg t "$TARGET" '.[$t] // empty' "$ITEM_IDS_PATH")"
if [ -z "$PUBLISHED_FILE_ID" ]; then
  echo "ERROR: unknown target '$TARGET' (expected test or prod, per $ITEM_IDS_PATH)." >&2
  exit 2
fi
# ERemoteStoragePublishedFileVisibility: 0 = public, 3 = unlisted. Test stays unlisted.
if [ "$TARGET" = "prod" ]; then VISIBILITY=0; else VISIBILITY=3; fi

# Changenote comes inline or from a bbcode file — never both.
if [ -n "$CHANGENOTE_FILE" ]; then
  if [ -n "$CHANGENOTE" ]; then
    echo "ERROR: pass either an inline changenote or --changenote-file, not both." >&2
    exit 2
  fi
  if [ ! -f "$CHANGENOTE_FILE" ]; then
    echo "ERROR: changenote file not found: $CHANGENOTE_FILE" >&2
    exit 2
  fi
  CHANGENOTE="$(cat "$CHANGENOTE_FILE")"
fi

# --- Preconditions ----------------------------------------------------------------------
if ! command -v steamcmd >/dev/null 2>&1 && [ "$DRY_RUN" -ne 1 ]; then
  echo "ERROR: steamcmd not found on PATH." >&2
  echo "       Install it (see docs/RELEASING.md)." >&2
  exit 127
fi
if [ "$DRY_RUN" -ne 1 ] && [ -z "$STEAM_USER" ]; then
  read -r -p "Steam username: " STEAM_USER
fi

# Build fresh so we never publish stale content.
VER="$(grep '^modversion=' "Contents/mods/$MOD_NAME/42/mod.info" | head -n1 | cut -d= -f2 | tr -d '\r' | xargs)"
bash "$(dirname "${BASH_SOURCE[0]}")/package.sh" "v$VER"

# The workshop item root must contain mods/ directly (the in-game uploader stripped the
# Contents wrapper itself), so upload Contents' contents — not the stage root.
CONTENT_FOLDER="$(cd "./dist/$MOD_NAME/Contents" && pwd)"
PREVIEW_FILE="$(cd "$(dirname "./preview.png")" && pwd)/$(basename "./preview.png")"
[ -n "$CHANGENOTE" ] || CHANGENOTE="v$VER"

# --- Fill the stored VDF template -------------------------------------------------------
# Escape a substituted value for a VDF quoted string: backslash first, then double-quote
# (same rule as the .ps1 twin). Newlines need no escaping — VDF quoted strings take them
# literally (the template's multiline description relies on this), so a file-sourced
# multiline changenote is fine. Plain bash substitution (not sed on the whole doc) so
# embedded newlines in CHANGENOTE round-trip correctly.
vdf_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

TEMPLATE="$(cat "workshop/workshop.vdf")"
VDF="${TEMPLATE//\{\{PUBLISHEDFILEID\}\}/$PUBLISHED_FILE_ID}"
VDF="${VDF//\{\{CONTENTFOLDER\}\}/$(vdf_escape "$CONTENT_FOLDER")}"
VDF="${VDF//\{\{PREVIEWFILE\}\}/$(vdf_escape "$PREVIEW_FILE")}"
VDF="${VDF//\{\{CHANGENOTE\}\}/$(vdf_escape "$CHANGENOTE")}"
VDF="${VDF//\{\{VISIBILITY\}\}/$VISIBILITY}"

mkdir -p ".publish"
VDF_PATH="$(pwd)/.publish/workshop.vdf"
printf '%s' "$VDF" > "$VDF_PATH"

echo "Wrote VDF -> $VDF_PATH"
echo "Content:  $CONTENT_FOLDER"
echo "Preview:  $PREVIEW_FILE"
echo "Target:   $TARGET -> item $PUBLISHED_FILE_ID (app $APP_ID)  changenote: $CHANGENOTE"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "--- DRY RUN: VDF contents (not uploading) ---"
  cat "$VDF_PATH"
  exit 0
fi

echo "Uploading via steamcmd..."
steamcmd +login "$STEAM_USER" +workshop_build_item "$VDF_PATH" +quit
echo "Published item $PUBLISHED_FILE_ID. Verify the page at"
echo "  https://steamcommunity.com/sharedfiles/filedetails/?id=$PUBLISHED_FILE_ID"
