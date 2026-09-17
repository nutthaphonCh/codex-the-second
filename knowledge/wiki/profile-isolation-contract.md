---
name: profile-isolation-contract
description: CODEX_HOME and CODEX_ELECTRON_USER_DATA_PATH must both be set, because Codex only honours the first when the second is present.
metadata:
  type: wiki
---

A profile launch passes exactly three things:

```
CODEX_HOME=~/.codex-<slug>
CODEX_ELECTRON_USER_DATA_PATH=~/.codex-<slug>/electron-user-data
--user-data-dir=~/.codex-<slug>/electron-user-data
```

**Both variables are required. This is not redundancy.**

During startup Codex loads the user's login-shell environment and merges it over
its own process environment. A `CODEX_HOME` exported from `.zshrc` would
therefore win and quietly undo the isolation. Codex re-applies the launch-time
value afterwards — but only when `CODEX_ELECTRON_USER_DATA_PATH` is also set.
Its own logic reduces to:

```js
// re-apply the launch-time CODEX_HOME, but only if an explicit
// Electron user-data path was given
const pinned = process.env.CODEX_ELECTRON_USER_DATA_PATH?.trim()
  ? process.env.CODEX_HOME
  : undefined
```

The same variable also decides the Electron `userData` location and, separately,
the single-instance behaviour described in [[single-instance-locking]].

`--user-data-dir` matches what Codex's own internal profile launcher passes. It
is belt-and-braces; the environment variable is what actually governs.

Directories are created at mode `0700` **before** the process starts, so the
profile exists before Electron initialises. Existing directories are never
touched: no migration, no reset, no rewriting.

A profile whose `codexHome` resolves to `~/.codex` — or anywhere inside it — is
rejected before launch. That guard is in `launch-plan.swift` and is covered by
unit tests.

Related: [[codex-desktop-bundle]], [[launch-without-launchservices]]
