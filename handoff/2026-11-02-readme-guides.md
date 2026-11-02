# Split the README into a summary and guides

PR #44 · Claude · 2026-11-02

## What changed
- `README.md` is now the summary: will it work, install, uninstall, the `galaxybook-fan` command, a Documentation table and a short safety list.
- Three new guides in `docs/`: `how-it-works.md`, `installing.md` and `compatibility-and-updates.md`.
- `PLAN.md` (rule 5 and the file map) and `AGENTS.md` now mention `docs/`.

## Why
- David wanted the same layout as `snapper_tray`. The README was about 3,200 words.

## Tested
- A script moved the text, then every line of the old README was compared with the new files. The only differences are the ones listed in the PR.
- A script checked every relative link, every full link to `docs/`, and their anchors.
- Checked how GitHub renders the README and guides on the branch.
- Not tested: the full links to `docs/` on GitHub, which only work once this is merged. No code changed, so no package or install test was needed.

## For the next person
- The packages install only `README.md`, so its links to the guides are full GitHub addresses. Links between guides are relative.
- Keep the heading *Will it work on my laptop?* and the *Confirmed working* table in the README: `works_on.yml`, `config.yml`, `pkg-pre.sh.in` and `lib/models.sh` point to them.
- Other repos weren't checked for links to this README's old anchors.
