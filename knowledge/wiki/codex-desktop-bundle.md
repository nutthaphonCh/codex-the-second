---
name: codex-desktop-bundle
description: Codex Desktop installs as ChatGPT.app with the com.openai.codex identifier, so the launcher must discover it rather than hardcode a path.
metadata:
  type: wiki
---

Codex Desktop is **not** installed at `/Applications/Codex.app`. On a current
macOS install it is:

```
/Applications/ChatGPT.app
  CFBundleIdentifier      com.openai.codex
  CFBundleExecutable      ChatGPT
  CFBundleName            ChatGPT
```

So the intuitive target — `/Applications/Codex.app/Contents/MacOS/Codex` —
matches neither the bundle nor the executable name. Hardcoding it produces a
launcher that never works.

It is an Electron application: `Contents/Resources/app.asar`, plus a
`Codex Framework.framework` (a Chromium build) supplying the Renderer, GPU and
Service helper processes.

Two consequences the code depends on:

- **The executable name is read from `Info.plist`** (`CFBundleExecutable`),
  never assumed. See `codex-app-locator.swift`.
- **`ChatGPT.app` is only accepted once its identifier proves it is Codex.**
  A machine can have the ordinary ChatGPT app at the same path; launching that
  instead would be wrong. Paths named `Codex.app` are accepted on name alone,
  since nothing else claims them.

## Search order

Fixed and total, so the result is deterministic when more than one candidate
exists — first match wins, and the list is short on purpose:

1. `CODEX_THE_SECOND_CODEX_APP` (one launch)
2. `codexAppPath` in the profile
3. `~/Library/Application Support/CodexTheSecond/codex-app-path`
4. `/Applications/Codex.app`, `/Applications/Codex Desktop.app`
5. the same two under `~/Applications`
6. `/Applications/ChatGPT.app`, then `~/Applications/ChatGPT.app` — accepted
   **only** if the identifier is `com.openai.codex`
7. a LaunchServices *lookup* by identifier

**There is deliberately no filesystem-wide search.** A `mdfind`-style sweep is
slow, can surface copies in `~/Downloads` or a mounted DMG, and makes the choice
non-obvious. Anywhere unusual is supported through 1–3 instead; that limitation
is documented in the README rather than engineered around.

Failure cases, all covered by tests or by the error type:

| Case | Behaviour |
| --- | --- |
| nothing found | alert listing every path searched, exit 1 |
| bundle exists, no readable `Info.plist` | rejected, skips to the next candidate |
| `Info.plist` names no executable | rejected with that reason |
| executable missing, or present but not executable | rejected with that reason |
| `ChatGPT.app` that is the ordinary ChatGPT app | skipped — identifier does not match |
| several valid candidates | the first in the order above |
| an **explicit** path (1–3) that is unusable | **fails loudly** — never falls through, because a pinned path that is wrong is a mistake worth surfacing |

The LaunchServices step only resolves a path; starting the app is always a
direct spawn, per [[launch-without-launchservices]].

Related: [[profile-isolation-contract]], [[upstream-behaviour-watch]]
