# Security

galaxybook-fan's installer and packages run as root, build a kernel module and handle Secure Boot signing keys. If you find a way it could be misused, such as running something as root that it shouldn't, weakening Secure Boot, or loading the module where it shouldn't load, please tell us privately first.

## How to report

- **Use GitHub's private reporting:** on this repository's **Security** tab, choose **Report a vulnerability**. Only you and the maintainer can see the report.
- Please **don't open a public issue** with the details until a fix is released.
- Say which version you have (`galaxybook-fan status` shows it), your laptop model, your distro and kernel, and the steps that show the problem.

You'll get a reply as soon as possible, usually within a few days. When it's fixed, the release notes say so, with credit to you if you'd like it.

## Which versions

Only the newest release gets fixes. Update first (`sudo galaxybook-fan update`) and check the problem is still there.

## What's covered elsewhere

The kernel, DKMS, your distro's signing tools (akmods, `mokutil`, `sbctl`) and Samsung's firmware belong to their own projects.
