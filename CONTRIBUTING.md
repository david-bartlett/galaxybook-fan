# Contributing

Thanks for helping. The most useful things, in order:

1. **Tell us it works on your laptop:** run the [check script](README.md#will-it-work-on-my-laptop), then post its report with the [**Works on my model**](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=works_on.yml) form. That's how [Compatibility](docs/compatibility.md) grows.
2. **Report a problem:** the [**Bug report**](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=bug_report.yml) form. Security problems: [SECURITY.md](SECURITY.md) instead, privately.
3. **Send a fix or a feature** as a pull request.

## Pull requests

- **Read [PLAN.md](PLAN.md) first.** It explains how the project works, every file, how to test (§8) and the safety rules (§9: the installer runs as root, builds a kernel module and handles Secure Boot keys).
- **One topic per pull request,** from its own branch, against `main`.
- **Add a line under `## Unreleased` in [CHANGELOG.md](CHANGELOG.md)** for anything users will notice, and update `README.md` or `docs/` where they describe what you changed.
- **Add a short note to [`handoff/`](handoff/README.md)** saying what changed and what the next person needs to know.
- **Say how you tested it** and what you couldn't test, especially on which laptop, distro and kernel.
- **Don't change `VERSION`** (or the versions in `module/dkms.conf` and `install.sh`), or make tags or releases: the maintainer releases after testing on his own laptop.

## Using AI tools

Welcome, as long as you understand the change and have tested it. Say so in the pull request, for example with an `Assisted-by:` or `Co-Authored-By:` line in the commit message. Much of this project is written that way too: see [How it's built and tested](README.md#how-its-built-and-tested). Coding agents should read [AGENTS.md](AGENTS.md).

## Style

British English.
