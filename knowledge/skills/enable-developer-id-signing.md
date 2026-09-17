---
name: enable-developer-id-signing
description: Turn on signing, notarization and stapling by adding secrets - no code changes.
metadata:
  type: skill
---

**Why:** signing was deliberately separated from compilation, so switching it on
must never require editing the build. If you find yourself changing
`build.sh` to sign, something has been wired wrong.

**How to apply:** add these repository secrets. Each group is independent —
signing without notarization works, and produces a build Gatekeeper trusts less
than a notarized one but more than ad-hoc.

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

Related: [[signing-and-gatekeeper]], [[cut-a-release]]
