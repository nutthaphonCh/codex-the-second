---
name: signing-and-gatekeeper
description: Releases are ad-hoc signed, what that costs users, and which parts are already wired for a Developer ID certificate.
metadata:
  type: wiki
---

There is no Apple Developer certificate for this project, so released builds are
**ad-hoc signed** (`codesign --sign -`).

What that means:

- The app runs fine locally and its signature verifies.
- It is **not** trusted by Gatekeeper on another machine. A downloaded build
  shows "cannot be opened because Apple cannot check it for malicious software".
- The documented way through is right-click → **Open** → confirm, once.
- Disabling Gatekeeper system-wide is never suggested, and should not be.
- Building from source locally avoids the prompt entirely.

Signing is kept out of compilation on purpose. `scripts/build.sh` always calls
`scripts/sign.sh`, which defaults to `-` (ad-hoc) and upgrades itself when
`CODESIGN_IDENTITY` is set — adding `--options runtime --timestamp`, which
notarization requires and which are pointless for ad-hoc.

`scripts/notarize.sh` exits 0 doing nothing unless all three Apple credentials
are present, so the release workflow can call it unconditionally.

Nothing about the build changes when a certificate appears; only secrets. See
[[enable-developer-id-signing]].

Related: [[toolchain-constraints]], [[cut-a-release]]
