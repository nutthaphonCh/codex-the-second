# Codex the 2nd

Starts the user's **existing** Codex Desktop install with an isolated profile, so
a second account runs beside the first. It does not contain, modify or
redistribute Codex.

## Hard rules

These are here rather than behind a link because following a link is optional
and these are not. Everything else is routed.

- **Never touch `~/.codex`** — no writes, no migration, no reset. A profile
  pointed at it is rejected before launch, and that guard has tests.
- **Never log, print or copy auth tokens.** Compare auth files by metadata only.
- **Never launch Codex with `open`/LaunchServices** — it can route into a
  running Codex that then ignores the profile. Spawn it directly.
- **Never bundle, copy or patch Codex**, and never use a `com.openai.*` bundle
  identifier.

## Before pushing

```bash
./scripts/check-tested-version.sh                   # docs agree with tested-with.json
./scripts/check-knowledge.sh                        # frontmatter, links, routes
./scripts/test.sh                                   # unit tests
./scripts/build.sh                                  # -> dist/Codex the 2nd.app
./scripts/validate-bundle.sh "dist/Codex the 2nd.app"
```

## Everything else

**[knowledge/README.md](knowledge/README.md) is the route table** — find what you
are about to do, and it names the entry to read. Conventions, release rules,
toolchain quirks and the reasoning behind every design decision live there, each
in exactly one place.
