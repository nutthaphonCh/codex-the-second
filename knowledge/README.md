# Knowledge

One fact or one procedure per file, each with frontmatter, linked to its
neighbours with `[[wiki-links]]`. This file is the index: one line per entry,
never the content itself.

Frontmatter on every entry:

```yaml
---
name: <skewer-case slug, matches the filename>
description: <one line, used to decide whether the entry is relevant>
metadata:
  type: wiki | skill | reference
---
```

`wiki` is how something is; `skill` is how to do something, and carries
**Why:** and **How to apply:** lines; `reference` points at things that live
elsewhere.

## Wiki

- [Codex Desktop bundle](wiki/codex-desktop-bundle.md) — Codex ships as `ChatGPT.app`, so the path in every obvious tutorial is wrong.
- [Profile isolation contract](wiki/profile-isolation-contract.md) — why both environment variables are required, not belt-and-braces.
- [Single instance locking](wiki/single-instance-locking.md) — why two Codex instances can coexist at all.
- [Launch without LaunchServices](wiki/launch-without-launchservices.md) — why `open` is never used to start Codex.
- [Signing and Gatekeeper](wiki/signing-and-gatekeeper.md) — what unsigned costs, and the parts already wired for a certificate.
- [Toolchain constraints](wiki/toolchain-constraints.md) — what Command Line Tools can and cannot do versus full Xcode.
- [Naming conventions](wiki/naming-conventions.md) — skewer-case everywhere, and the names tooling refuses to let us choose.
- [GitHub rendering limits](wiki/github-rendering-limits.md) — the SVG features GitHub's sanitizer may drop.

## Skills

- [Add a new profile](skills/add-a-new-profile.md) — ship `Codex Work.app` without touching Swift.
- [Cut a release](skills/cut-a-release.md) — version, tag, and what the pipeline does unattended.
- [Verify profile isolation](skills/verify-profile-isolation.md) — prove the profiles are actually separate, without reading tokens.
- [Enable Developer ID signing](skills/enable-developer-id-signing.md) — the secrets to add; no code changes needed.
- [Debug a failed launch](skills/debug-a-failed-launch.md) — what to check when Codex will not start.

## Reference

- [Repository map](reference/repository-map.md) — what lives where and why.
- [Upstream behaviour watch](reference/upstream-behaviour-watch.md) — the Codex internals this project leans on, and what breaks if they change.
