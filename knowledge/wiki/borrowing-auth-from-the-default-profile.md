---
name: borrowing-auth-from-the-default-profile
description: Why a profile may be allowed to read the main profile's authentication, and why that permission is configuration plus a skill rather than code.
metadata:
  type: wiki
---

Profiles exist to keep two accounts apart. `allowAuthFromDefaultProfile` puts a
hole in that on purpose, so the reasoning is written down here.

## Why it exists

macOS delivers `codex://` callbacks by bundle identifier, and both instances
share `com.openai.codex`. A connector or plugin sign-in started in the second
profile can therefore land in the **main** window — see
[[single-instance-locking]] for why the two instances coexist at all. The clean
fix is to quit the main app and authenticate again with only the second running.
When that is not practical, the owner of both accounts may prefer to reuse what
the main profile already has.

## Why it is a skill, not a feature

The launcher does not read, copy or move credentials, and nothing here changes
that. What the flag does is install
`<CODEX_HOME>/skills/codex-the-second-profile/SKILL.md`, which tells the agent:

- it may read under `~/.codex` **only after asking, each time**, naming the
  path, the reason, and what it will do with it
- one yes covers one access; silence is never consent
- `auth.json` is account sign-in, and using it makes the instance act **as the
  other account** — a consequence to state out loud before asking
- writing to `~/.codex` is never allowed, flag or not
- tokens are never printed, and nothing is copied wholesale

That is guidance an agent follows, not a boundary the launcher enforces. The
distinction matters and should not be blurred in documentation: the
[[profile-isolation-contract]] and the filesystem guard remain absolute, while
this is a permission the user grants in configuration.

## Defaults

Off unless a profile sets it. The profile shipped here sets it, because one
person owns both accounts. Turning it off rewrites the skill to put the main
profile out of bounds — the permission is withdrawn on the next launch, not left
behind in a stale file.

Related: [[profile-isolation-contract]], [[single-instance-locking]]
