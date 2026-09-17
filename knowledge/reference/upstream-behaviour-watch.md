---
name: upstream-behaviour-watch
description: The Codex Desktop internals this project depends on, and how each one fails if it changes.
metadata:
  type: reference
---

None of this is a public API. It is observed behaviour of Codex Desktop, and a
future Codex release may change any of it. Recorded so a breakage can be
diagnosed in minutes instead of rediscovered.

Observed against **Codex Desktop 26.908.40834** on macOS 26.5.2 (Apple Silicon).

That version lives in [`tested-with.json`](../../tested-with.json) at the
repository root — one source of truth, published in every release's notes and
title. CI fails if a document quotes a different version, so update the JSON
first and only after re-running [docs/verification.md](../../docs/verification.md).

| Depends on | Currently | If it changes |
| --- | --- | --- |
| Bundle location and identifier | `/Applications/ChatGPT.app`, `com.openai.codex` | discovery fails; alert names every path searched. Fix: pin the path, then add the new location to the candidate list |
| Executable name | `ChatGPT`, read from `CFBundleExecutable` | already dynamic; nothing to do |
| `CODEX_HOME` | selects the Codex profile directory | profile silently shares `~/.codex`. **Worst case** — the safety rail only catches a misconfigured profile, not Codex ignoring the variable |
| `CODEX_ELECTRON_USER_DATA_PATH` | selects Electron `userData`, and re-pins `CODEX_HOME` over the login-shell environment | isolation partially collapses; check `--print-plan` still matches the running process environment |
| Single-instance predicate | `isPackaged && (!isMacOS \|\| hasExplicitUserDataPath)` | either a second instance refuses to start, or relaunch spawns duplicates |
| `--user-data-dir` | accepted; matches Codex's own internal profile launcher | harmless if ignored, since the environment variable governs |
| Startup exit behaviour | exits 0 when the lock is held | a non-zero exit would surface a spurious "exited immediately" alert |

How to re-check after a Codex update:

```bash
# bundle identity
defaults read /Applications/ChatGPT.app/Contents/Info.plist CFBundleIdentifier

# the variables are still referenced by the app
cd /Applications/ChatGPT.app/Contents/Resources
for v in CODEX_HOME CODEX_ELECTRON_USER_DATA_PATH user-data-dir; do
  printf "%-32s " "$v"; LC_ALL=C grep -a -c -- "$v" app.asar
done
```

Then run [docs/verification.md](../../docs/verification.md) — process, environment and filesystem
isolation is what actually matters, not whether the strings are still present.

The failure mode to care about is **silent**: Codex starting on the default
profile while appearing to honour the isolated one. Comparing `--print-plan`
against the running process's real environment is what catches it.

Related: [[codex-desktop-bundle]], [[profile-isolation-contract]], [[single-instance-locking]]
