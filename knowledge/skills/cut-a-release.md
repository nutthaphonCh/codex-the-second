---
name: cut-a-release
description: Publish a new version - bump VERSION, tag, and let the workflow build, package and publish unattended.
metadata:
  type: skill
---

**Why:** the release workflow refuses to run if `VERSION` and the tag disagree,
so the bump is not optional book-keeping — skipping it fails the build rather
than shipping a mislabelled artifact.

**How to apply:**

0. If Codex Desktop has changed since the last release, re-run
   [[verify-profile-isolation]] and update `tested-with.json` first. Every
   release publishes the Codex build it was verified against, in both the
   release title and a **Tested against** table in the notes — CI fails if any
   document quotes a different version.

1. Bump the version and commit it:

   ```bash
   echo "0.3.0" > VERSION
   git commit -am "chore: bump version to 0.3.0"
   ```

2. Tag and push:

   ```bash
   git tag -a v0.3.0 -m "v0.3.0"
   git push origin main
   git push origin v0.3.0
   ```

The tag triggers `.github/workflows/release.yml`, which then:

1. checks `VERSION` matches the tag, and stops if not
2. runs the unit tests
3. imports a signing certificate — only if the secrets exist
4. builds the universal `.app` and validates the bundle
5. packages the DMG and ZIP
6. notarizes and staples — only if the Apple credentials exist
7. writes `SHA256SUMS.txt` *after* notarization, since stapling changes the hash
8. creates the GitHub release with notes matching the actual signing state

Artifacts land as `Codex-the-2nd-vX.Y.Z.dmg`, `.zip`, and `SHA256SUMS.txt`.

Afterwards, verify what was actually published rather than what was built:

```bash
gh release download vX.Y.Z --dir /tmp/rel && cd /tmp/rel
shasum -a 256 -c SHA256SUMS.txt
```

Nothing third-party is used to publish; it is `gh release create` with the
built-in token.

Related: [[signing-and-gatekeeper]], [[verify-profile-isolation]]
