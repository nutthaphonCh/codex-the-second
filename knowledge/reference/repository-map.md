---
name: repository-map
description: What lives where, and which files you actually have to touch for a given change.
metadata:
  type: reference
---

```
codex-the-second/
├── Package.swift                  SwiftPM manifest (name fixed by the tool)
├── VERSION                        single source of truth for the version
├── profiles/
│   ├── personal.json              the shipped profile
│   └── work.json.example          template for a second one
├── Sources/
│   ├── CodexTheSecond/
│   │   └── main.swift             entry point, native alerts, --print-plan
│   └── CodexTheSecondCore/
│       ├── profile.swift          the profile model and its JSON loading
│       ├── path-resolver.swift    tilde expansion, containment checks
│       ├── codex-app-locator.swift  discovery and bundle inspection
│       ├── launch-plan.swift      validation and the launch command
│       ├── profile-launcher.swift directory creation and the spawn
│       └── launcher-error.swift   every failure, phrased for a dialog
├── Tests/CodexTheSecondCoreTests/ 36 tests, swift-testing
├── scripts/
│   ├── build.sh                   profile JSON -> signed .app
│   ├── package.sh                 .app -> DMG, ZIP, checksums
│   ├── sign.sh                    ad-hoc by default, Developer ID if configured
│   ├── notarize.sh                no-op unless credentials exist
│   ├── import-certificate.sh      CI-only, temporary keychain
│   ├── validate-bundle.sh         structural checks, run by CI
│   ├── make-icon.swift            generates the icon with CoreGraphics
│   └── test.sh                    handles the CLT swift-testing paths
├── docs/
│   ├── verification.md            manual isolation procedure and results
│   └── assets/hero.svg            README banner
├── knowledge/                     this knowledge base
└── .github/workflows/
    ├── ci.yml                     build, test, validate, package
    └── release.yml                same, plus publish on a v* tag
```

Where to make a given change:

| Change | Touch |
| --- | --- |
| Add a profile | `profiles/<slug>.json` only |
| Change isolation behaviour | `launch-plan.swift` (+ its tests) |
| Change how Codex is found | `codex-app-locator.swift` (+ its tests) |
| Change an error message | `launcher-error.swift` |
| Change bundle metadata | the `Info.plist` heredoc in `build.sh` |
| Change artifact names | `ARTIFACT_BASE` in `package.sh` |
| Change the version | `VERSION`, nothing else |

The launcher reads its profile from `Contents/Resources/profile.json` inside its
own bundle, which `build.sh` copies in. `CODEX_THE_SECOND_PROFILE_FILE`
overrides it for testing an unbundled binary.

Related: [[naming-conventions]], [[add-a-new-profile]]
