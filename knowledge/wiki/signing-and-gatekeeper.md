---
name: signing-and-gatekeeper
description: Releases are ad-hoc signed, what that costs users, and the secrets that switch on Developer ID signing and notarization.
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

## Switching it on

Nothing about the build changes when a certificate appears — only secrets. Add
these to the repository and the release workflow starts signing, notarizing and
stapling on its own.

**Signing**

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | `base64 -i cert.p12` of a Developer ID Application certificate |
| `MACOS_CERTIFICATE_PASSWORD` | password for that `.p12` |
| `MACOS_SIGNING_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |

**Notarization**

| Secret | Value |
| --- | --- |
| `APPLE_ID` | Apple ID email |
| `APPLE_TEAM_ID` | developer team identifier |
| `APPLE_APP_PASSWORD` | app-specific password, not the account password |

That is the whole change. The release workflow already:

- imports the certificate into a temporary, single-use keychain and publishes
  its path through `GITHUB_ENV`
- passes `CODESIGN_IDENTITY` to `scripts/sign.sh`, which then adds
  `--options runtime --timestamp`
- calls `scripts/notarize.sh`, which becomes a real submission instead of a
  no-op
- recomputes `SHA256SUMS.txt` after stapling
- writes release notes that say the build is signed rather than ad-hoc

Locally, one variable does the same thing:

```bash
CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build.sh
```

Never commit a `.p12`, a password, or an exported certificate. `.gitignore`
already excludes `*.p12`, `*.cer` and `*.provisionprofile`.

The release workflow already imports the certificate into a temporary,
single-use keychain, publishes its path through `GITHUB_ENV`, recomputes
`SHA256SUMS.txt` after stapling, and writes notes that say the build is signed.
Locally, one variable does the same:

```bash
CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build.sh
```

Never commit a `.p12`, a password or an exported certificate; `.gitignore`
already excludes them.

Related: [[toolchain-constraints]], [[cut-a-release]]
