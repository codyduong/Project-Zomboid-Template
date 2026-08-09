# Project-Zomboid-Template

A GitHub template repo + shared script library for Project Zomboid Build 42 mods: mise
tasks, PowerShell build/deploy/publish/testhost scripts, lint/format config, and CI
workflows — factored out of [PlumbingFixed](https://github.com/codyduong/PlumbingFixed) so
new mods don't start from a blank toolchain, and so fixes to the toolchain can reach every
mod that uses it.

Two ways this repo is consumed, see [docs/USING-THIS-TEMPLATE.md](docs/USING-THIS-TEMPLATE.md):

1. **Scaffold a new mod** — "Use this template" on GitHub (or clone), run
   `bootstrap.ps1 -ModName YourMod` once, then add this repo as a `tooling/` git
   submodule.
2. **Stay in sync** — `mise run sync-template` (defined in every scaffolded mod's
   `mise.toml`) pulls the latest `tooling/` commit. Pin/skip to freeze, or deinit the
   submodule to fully vendor and diverge.

`scripts/` is the part that's actually submoduled and shared live; `templates/` is scaffolded
once per mod repo and then owned by that repo (never synced again) — see
[docs/USING-THIS-TEMPLATE.md](docs/USING-THIS-TEMPLATE.md) for why the split is drawn there.
