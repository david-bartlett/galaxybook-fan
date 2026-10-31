# Instructions for coding agents

Read **[PLAN.md](PLAN.md)** before starting: it explains how the project works, every file, and how changes are made. The essentials:

- **Every change is a pull request** against `main`, from its own branch. Never push to `main`, never merge, never force-push.
- **Never release:** don't change `VERSION` (or the version in `module/dkms.conf` and `install.sh`), don't create `v*` tags or GitHub releases. David releases himself, after testing the PR on his laptop.
- **One topic per PR.** Check a PR isn't merged before pushing more to its branch.
- **User-visible change → a line under `## Unreleased` in `CHANGELOG.md`** (a short bold headline line, then plain detail lines; see PLAN.md §7.2), and update `README.md` where it describes what you changed.
- In the PR description: what changed, how you tested it, what you couldn't test, and numbered steps for David to test it on the laptop (PLAN.md §8).
- **Add a handoff note** to `handoff/` in every PR (see [handoff/README.md](handoff/README.md)), and **read the notes newer than your last session** before starting. When a PR changes how something works, update `PLAN.md` in the same PR.
- Before committing: `bash -n` on changed scripts (and on the output of `tools/build-check-script.sh` if you change the check script, `lib/models.sh` or the parser), `python3 -m py_compile lib/dsdt-fan-config.py`, and check `git status` for stray files (no `__pycache__`, `.o`, `.ko`). Keep test scripts outside the repository.
- **Paths and names live in `lib/fanpaths.sh`**: don't hard-code them again in a script. A change to how the config is made goes in `module/gen-config.sh` (DKMS) and is shown by `install.sh --check` with the same parser.
- The installer runs as root, builds a kernel module and handles Secure Boot keys: read PLAN.md §9 (safety) before changing anything that writes system files, signs modules or touches the EC.
- British English.
