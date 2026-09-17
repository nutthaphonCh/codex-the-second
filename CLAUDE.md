# Working in this repository

A macOS launcher that starts the user's **existing** Codex Desktop install with
an isolated profile, so a second account can run beside the first. It does not
contain, modify or redistribute Codex.

Depth lives in [`knowledge/`](knowledge/README.md) — start at its index. This
file is the short version: the rules that are easy to break by accident.

## Never

- **Never touch `~/.codex`.** No reads that matter, no writes, no migration, no
  reset. It belongs to the user's normal install. A profile pointed at it is
  rejected before launch, and that guard has tests — do not weaken it.
- **Never log, print or copy auth tokens.** `--print-plan` emits only
  `CODEX_HOME` and `CODEX_ELECTRON_USER_DATA_PATH`, never the inherited
  environment; a test asserts that. Compare auth files by metadata only.
- **Never launch Codex with `open`/LaunchServices.** It can route the request
  into an already-running Codex, which then ignores the profile. Spawn it
  directly — see [`knowledge/wiki/launch-without-launchservices.md`](knowledge/wiki/launch-without-launchservices.md).
- **Never bundle, copy or patch Codex**, and never use a `com.openai.*` bundle
  identifier. CI fails the build if a profile tries.

## Conventions

- **Filenames are skewer-case**, Swift sources included. The exceptions are
  names tooling chooses for us — `Package.swift`, `main.swift`, `README.md`,
  `CLAUDE.md`, `LICENSE`, `VERSION`, and target directories matching their
  module names. Full list and reasoning:
  [`knowledge/wiki/naming-conventions.md`](knowledge/wiki/naming-conventions.md).
  Identifiers inside the code keep their language's convention.
- **Profiles are configuration, not code.** Adding `Codex Work.app` means adding
  `profiles/work.json` and nothing else. If a change requires editing Swift to
  add an account, it is the wrong change.
- **Build config is read with `plutil`**, which parses JSON natively, so the
  build stays on the Apple toolchain — no jq, no Python.
- **Signing stays out of compilation.** `scripts/build.sh` always calls
  `scripts/sign.sh`, which is ad-hoc until `CODESIGN_IDENTITY` is set. Never
  make compiling depend on a certificate existing.
- **Knowledge entries follow the local memory format** — frontmatter with
  `name`, `description` and `metadata.type`, `[[wiki-links]]`, one line per
  entry in the index. `scripts/check-knowledge.sh` enforces it.

## Before pushing

```bash
./scripts/check-knowledge.sh                        # frontmatter, links, index
./scripts/test.sh                                   # 36 unit tests
./scripts/build.sh                                  # -> dist/Codex Personal.app
./scripts/validate-bundle.sh "dist/Codex Personal.app"
```

CI runs all four plus a release-metadata check. Behaviour that only the real app
can prove — process, environment, filesystem and auth isolation — is verified by
hand: [`docs/verification.md`](docs/verification.md).

## Releases

- `VERSION` is the single source of truth. The release workflow fails if it
  disagrees with the tag.
- **Every release states the Codex Desktop build it was tested against**, in the
  release title and the notes. That value lives in
  [`tested-with.json`](tested-with.json) and nowhere else; CI fails if a document
  quotes a different version.
- Update `tested-with.json` only after re-running `docs/verification.md` against
  the new Codex.

Procedure: [`knowledge/skills/cut-a-release.md`](knowledge/skills/cut-a-release.md).

## The one failure mode that matters

Codex starting on the **default** profile while appearing to honour the isolated
one. It is silent, and it puts one account's data in front of the other. Any
change to environment handling, discovery or launch must be checked against the
running process's real environment, not just against the plan:

```bash
ps -E -o command= -p <pid> | tr ' ' '\n' | grep '^CODEX_'
```

What this project relies on inside Codex, and how each piece fails:
[`knowledge/reference/upstream-behaviour-watch.md`](knowledge/reference/upstream-behaviour-watch.md).
