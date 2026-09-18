---
name: naming-conventions
description: Files are skewer-case; the exceptions are names the toolchain or GitHub refuses to let us choose.
metadata:
  type: wiki
---

**Every file we name is skewer-case** (lowercase, hyphen-separated):

```
sources      path-resolver.swift, codex-app-locator.swift, launch-plan.swift
tests        path-resolver-tests.swift, launch-plan-tests.swift
scripts      build.sh, make-icon.swift, validate-bundle.sh, import-certificate.sh
docs         verification.md, assets/hero.svg
knowledge    wiki/single-instance-locking.md, skills/cut-a-release.md
profiles     personal.json, work.json.example
workflows    ci.yml, release.yml
```

This departs from Swift's usual PascalCase-per-type filenames. SwiftPM does not
care what source files are called, so the cost is zero and the repo reads
consistently.

**Exceptions, all forced:**

| Name | Why it cannot be skewer-case |
| --- | --- |
| `Package.swift` | SwiftPM requires this exact filename |
| `main.swift` | required for an executable target's top-level code |
| `README.md` | GitHub renders it; `knowledge/README.md` is the route table |
| `CLAUDE.md` | read automatically by Claude Code in this repository |
| `LICENSE` | GitHub's licence detection expects it |
| `VERSION` | conventional, and read by the build scripts |
| `Sources/`, `Tests/` | SwiftPM's default layout |
| `Sources/CodexTheSecondCore/` | must match the Swift module name |

**Identifiers inside the code keep their language's convention** — Swift types
are `PascalCase`, environment variables are `SCREAMING_SNAKE`. Skewer-case is a
filename rule, not a code-style rule.

Other naming that is fixed by the project rather than the tools:

- Product name: **Codex the 2nd**
- Swift module / bundle executable: `CodexTheSecond`
- Bundle identifier: `io.github.nutthaphonch.codex-the-second.<slug>`
- Environment overrides: `CODEX_THE_SECOND_*`
- Release artifacts: `Codex-the-2nd-vX.Y.Z.dmg`
- Generated app: `Codex <Profile>.app`, e.g. `Codex the 2nd.app`

Related: [the route table](../README.md)
