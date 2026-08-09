# Using this template

## What's shared live vs. scaffolded once

- **`scripts/`** — mounted as a git submodule (`tooling/`) in every consuming mod repo.
  Pure PowerShell logic with no per-repo state baked in (mod name is derived at runtime from
  the single folder under `Contents/mods/`, repo root is derived from the submodule's fixed
  mount path). Fixes/improvements here reach every mod that syncs.
- **`.github/workflows/lint.yml` / `release.yml`** — reusable (`workflow_call`) workflows.
  Consuming repos keep a thin caller workflow; no submodule needed, and pinning the caller's
  `uses:` ref to a tag (instead of `@main`) gives the same freeze option as the submodule has.
- **`templates/`** — copied into a new mod repo exactly once, by `bootstrap.ps1`, then
  owned by that repo forever. This is everything that's either **position-sensitive**
  (`.emmyrc.json`'s workspace `library` path embeds the mod name/path) or **inherently
  mod-specific** (mod.info, workshop listing, lore docs, CLAUDE.md). Never expect these to
  sync — editing them in a mod repo is normal, not a fork.

## Scaffolding a brand-new mod

1. On GitHub, **"Use this template"** on this repo (or `git clone` it and start a fresh
   history) into a new repo, e.g. `YourModName`.
2. From the new repo's root:
   ```
   pwsh -NoProfile -File bootstrap.ps1 -ModName YourModName
   ```
   This renames `templates/Contents/mods/__MOD_NAME__` → `.../YourModName`, replaces every
   `__MOD_NAME__` placeholder in `templates/`, strips `.tmpl` suffixes, copies `templates/*`
   to the repo root, deletes `templates/`, removes the full `scripts/` checkout this repo
   shipped (step 3 replaces it), rewrites `.github/workflows/{lint,release}.yml` into thin
   callers pointed at this template repo, removes this doc (it's about using the template,
   not about your mod), and deletes itself.
3. Add this repo as the shared-scripts submodule:
   ```
   git submodule add https://github.com/codyduong/Project-Zomboid-Template.git tooling
   ```
   Pin to a release tag once one exists (`git -C tooling checkout v1.0.0`) rather than
   tracking `main`, so the mod repo's builds stay reproducible; `git add tooling` after. Also
   re-run `bootstrap.ps1 -TemplateRef v1.0.0 ...` (or hand-edit the `uses:` refs in
   `.github/workflows/*.yml`) to pin CI to the same tag.
4. Fill in the mod-specific files `bootstrap.ps1` left as placeholders:
   `workshop/item-ids.json` (your Workshop test/prod item ids), `workshop/workshop.vdf`
   (title/description/tags), `preview.png`, `Contents/mods/YourModName/42/poster.png`.
5. `mise install && mise run check` to confirm the toolchain is wired up.

## Keeping a mod repo in sync

Every scaffolded `mise.toml` includes:
```
mise run sync-template
```
which runs `git submodule update --remote tooling && git add tooling`, then leaves the bump
staged for you to review (`git diff --staged tooling`) and commit. This updates `tooling/`
to whatever ref you've configured the submodule to track (defaults to the branch you set with
`git submodule set-branch`, or the commit you last checked out if none is set — an explicit
`git -C tooling checkout <tag>` before running this is the deliberate way to move to a
specific release).

## Diverging a mod repo permanently

If a mod needs to fork the shared scripts (not just pin an old version):
```
git submodule deinit tooling
git rm tooling
```
then copy the last-known-good `tooling/scripts/*` in directly and edit freely. From that
point the mod repo owns its own copy — pulling further template updates back in is a manual
merge, same as any vendored dependency.

## Design notes / why this boundary

- `.emmyrc.json`, `.luafmt.toml`, `.vscode/`, `mise.toml`, `CLAUDE.md`, `README.md`,
  `LICENSE`, doc skeletons, and the mod skeleton itself are **not** submoduled because they
  either embed the mod's own name/path (breaks if shared live) or are meant to be edited
  freely per mod (a shared, synced `CLAUDE.md` would fight every mod's own lore/architecture
  notes). Scaffold-once is the right lifecycle for these, not scaffold-and-sync.
- `scripts/*.ps1` do not hardcode `$MOD_NAME` — see `scripts/_common.ps1`. This is what
  makes the submodule genuinely zero-config per consuming repo: adding the submodule and
  wiring `mise.toml`'s `run` lines at `tooling/scripts/...` is the entire integration step.
