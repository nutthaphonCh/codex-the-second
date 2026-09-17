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

Search order is explicit override → known install locations → a LaunchServices
*lookup* by identifier. The lookup only resolves a path; starting the app is
always a direct spawn, per [[launch-without-launchservices]].

Related: [[profile-isolation-contract]], [[upstream-behaviour-watch]]
