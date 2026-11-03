# install.sh: read DKMS's signing settings as DKMS does

PR #54 · Claude · 2026-11-03

## What changed
- `dkms_effective_key` sources `/etc/dkms/framework.conf` and `framework.conf.d/*.conf` in order, in a subshell with `kernelver` set and `set +eu`, then expands any `${kernelver}` / `$kernelver` left in single quotes. With `all` it includes our own drop-in (what DKMS will use once it's written).
- `use_key`: after writing `galaxybook-fan-signing.conf`, checks `dkms_effective_key all` is that key. If not, it removes the drop-in, warns with the file(s) sorting after it that set `mok_*`, and returns 1. `setup_signing`'s enrolled and pending loops then try the next candidate. Step 3 falls back to the key DKMS is set to use.
- PLAN.md (install step 4), `docs/installing.md`, CHANGELOG.

## Why
- Codex review of `07c23bc`, findings 2 and 3 (one topic: which key DKMS signs with). The `sed` reader kept inline comments (`mok_certificate=/k/cert # cert`) and didn't expand `${kernelver}`. And a later file such as `zz-custom.conf` overrode our drop-in: install said "Signing with /var/lib/dkms/mok.pub (enrolled)", while DKMS signed with the unenrolled custom key.
- Sourcing is safe here: these are root-owned DKMS settings that DKMS itself sources as root. (Unlike the state file, PR #42, which is our own data.)

## Tested
- Extracted `key_state`, `dkms_effective_key`, `use_key` and `setup_signing`, with a fake `mokutil` and real files in a scratch `/etc/dkms` (in the sandbox). Covered: a quoted path with a comment, `${kernelver}` and single-quoted `$kernelver`, the default pair, later files winning.
- Codex's case (`zz-custom.conf` unenrolled, the default pair enrolled): the drop-in isn't left, the warning names `zz-custom.conf`, and the not-enrolled path for that key follows. With no later file, the default pair is used through our drop-in, as before.
- `bash -n`; shellcheck: no new warnings.
- Not here: a real Secure Boot install, real `mokutil`, DKMS really signing.

## For the next person
- The packages don't use this: they sign with whatever DKMS is set to and only report it (PLAN §10.2).
