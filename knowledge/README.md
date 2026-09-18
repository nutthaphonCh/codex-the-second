# Knowledge

**Route table first.** Find the row for what you are about to do; it names the
one entry that covers it. Each fact lives in exactly one file — `CLAUDE.md` at
the root holds only the hard rules and points here for the rest.

An entry earns its place by protecting the product: reverse-engineered Codex
behaviour, verified environment semantics, upstream compatibility, tooling traps
that cost real time. Anything that only restates the code, the README or
`docs/verification.md` does not belong here — it will drift, and drifted notes
are worse than none.

## Changing how the launcher works

| About to… | Read |
| --- | --- |
| change how Codex is located, or handle a moved/renamed bundle | [codex-desktop-bundle](wiki/codex-desktop-bundle.md) |
| touch environment variables or launch arguments | [profile-isolation-contract](wiki/profile-isolation-contract.md) |
| change how the process is spawned | [launch-without-launchservices](wiki/launch-without-launchservices.md) |
| work out why two instances can coexist, or why relaunch focuses | [single-instance-locking](wiki/single-instance-locking.md) |
| change what a profile may read from the main profile, or why sign-in lands in the wrong window | [borrowing-auth-from-the-default-profile](wiki/borrowing-auth-from-the-default-profile.md) |
| work out why a launch failed, or landed on the wrong account | [debug-a-failed-launch](skills/debug-a-failed-launch.md) — start with `c2nd doctor` |
| add `Codex Work.app` or another profile | the ["Want a third one?"](../README.md) section of the README |

## Building, testing, releasing

| About to… | Read |
| --- | --- |
| hit a toolchain oddity — universal binaries, swift-testing, `plutil`, bash 3.2 | [toolchain-constraints](wiki/toolchain-constraints.md) |
| publish a version | [cut-a-release](skills/cut-a-release.md) |
| prove the profiles really are isolated, or read what has actually been tested | [docs/verification.md](../docs/verification.md) |
| answer a Gatekeeper question, or switch on Developer ID signing | [signing-and-gatekeeper](wiki/signing-and-gatekeeper.md) |

## Writing files and docs

| About to… | Read |
| --- | --- |
| name a new file, or wonder why `Package.swift` is not skewer-case | [naming-conventions](wiki/naming-conventions.md) |
| edit the README banner or any SVG GitHub renders | [github-rendering-limits](wiki/github-rendering-limits.md) |

## When Codex updates

| About to… | Read |
| --- | --- |
| diagnose a breakage after a Codex release, or re-verify | [upstream-behaviour-watch](reference/upstream-behaviour-watch.md) |

---

## Writing an entry

One fact or one procedure per file, in the local memory format:

```yaml
---
name: <skewer-case slug, matches the filename>
description: <one line, used to decide whether the entry is relevant>
metadata:
  type: wiki | skill | reference
---
```

`wiki` is how something is. `skill` is how to do something, and carries **Why:**
and **How to apply:** lines. `reference` points at things that live elsewhere.
Link neighbours with `[[wiki-links]]`.

Record what was actually discovered — surprising behaviour, tooling limits,
decisions and their reasons — not a restatement of the code.

A new entry must be added to the route table above. `scripts/check-knowledge.sh`
enforces the frontmatter, resolves every `[[wiki-link]]` and relative link
(`CLAUDE.md`'s included), and fails if an entry is unrouted. CI runs it.
