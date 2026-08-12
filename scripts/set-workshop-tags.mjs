#!/usr/bin/env node
// Set Steam Workshop tags on an existing item -- steamcmd's `workshop_build_item` never
// calls ISteamUGC::SetItemTags (confirmed against PZ's own decompiled client,
// zombie.core.znet.SteamWorkshop#SubmitWorkshopItem: it calls n_SetItemTitle/
// n_SetItemDescription/n_SetItemVisibility/n_SetItemTags/n_SetItemContent/n_SetItemPreview
// as SEPARATE native calls in one update transaction -- steamcmd's VDF path only ever
// wires up the first, second, third, fifth, and sixth of those, never n_SetItemTags), so
// tags silently never apply no matter how the VDF is formatted. This calls the real
// ISteamUGC::SetItemTags via steamworks.js instead, updating ONLY tags (every other
// UgcUpdate field is left unset, so title/description/content/preview are untouched).
//
// Requires the Steam client running and logged in as the account that owns the item --
// unlike steamcmd, steamworks.js talks to the live Steam client, not a headless CLI login.
//
// Usage: node scripts/set-workshop-tags.mjs <test|prod>
//   (invoked via `mise run set-workshop-tags <test|prod>` in a mod repo -- see mise.toml)

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import steamworks from "steamworks.js";

const APP_ID = 108600;

// This file is designed to be mounted as a git submodule at <mod-repo>/tooling/scripts/
// (see docs/USING-THIS-TEMPLATE.md) -- the consuming repo root is two hops up, mirroring
// _common.ps1/_common.sh's Get-PZRepoRoot/pz_repo_root.
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

const target = process.argv[2];
if (target !== "test" && target !== "prod") {
  console.error(`ERROR: a target ("test" or "prod") is required, got: ${JSON.stringify(target)}`);
  process.exit(2);
}

const itemIdsPath = path.join(repoRoot, "workshop", "item-ids.json");
const itemIds = JSON.parse(readFileSync(itemIdsPath, "utf8"));
const itemId = itemIds[target];
if (!itemId || itemId === "0") {
  console.error(
    `ERROR: workshop/item-ids.json has no real "${target}" item id yet (still "0" or missing).`
  );
  console.error(`       Run "mise run publish ${target} ..." once first to create the item.`);
  process.exit(1);
}

// Single source of truth for tags stays workshop.vdf's own "tags" line, so there's no
// second place to keep them in sync -- extract it rather than re-declaring the list here.
const vdfPath = path.join(repoRoot, "workshop", "workshop.vdf");
const vdfText = readFileSync(vdfPath, "utf8");
const tagsMatch = vdfText.match(/^\s*"tags"\s*"([^"]*)"\s*$/m);
if (!tagsMatch) {
  console.error(`ERROR: couldn't find a "tags" "..." line in ${vdfPath}.`);
  process.exit(1);
}
const tags = tagsMatch[1]
  .split(",")
  .map((t) => t.trim())
  .filter(Boolean);
if (tags.length === 0) {
  console.error(`ERROR: the "tags" line in ${vdfPath} is empty.`);
  process.exit(1);
}

console.log(`Target:  ${target} -> item ${itemId} (app ${APP_ID})`);
console.log(`Tags:    ${tags.join(", ")}`);

const client = steamworks.init(APP_ID);

try {
  const result = await client.workshop.updateItem(BigInt(itemId), { tags }, APP_ID);
  if (result.needsToAcceptAgreement) {
    console.warn(
      "WARNING: Steam says the Workshop Legal Agreement still needs to be accepted for this item."
    );
  }
  console.log(`Tags updated on item ${result.itemId}.`);
  console.log(`Verify at https://steamcommunity.com/sharedfiles/filedetails/?id=${itemId}`);
} catch (err) {
  console.error("ERROR: steamworks.js updateItem failed:", err);
  console.error(
    "       Make sure the Steam client is running and logged in as the account that owns this item."
  );
  process.exit(1);
}
