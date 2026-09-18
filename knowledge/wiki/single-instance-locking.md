---
name: single-instance-locking
description: Codex takes an Electron single-instance lock only when an explicit user-data path is set, and the lock is scoped to that directory.
metadata:
  type: wiki
---

Why a second Codex can run at all, rather than being folded into the first.

Codex decides whether to enforce single-instance like this:

```
enforce = isPackaged && (!isMacOS || hasExplicitUserDataPath)
```

On packaged macOS that reduces to **`hasExplicitUserDataPath`** — meaning
`CODEX_ELECTRON_USER_DATA_PATH` is set. So:

| Instance | Explicit user-data path | Electron lock |
| --- | --- | --- |
| Normal Codex | no | not requested; macOS/LaunchServices keeps it single |
| Profile instance | yes | requested, inside its own user-data directory |

Electron's lock lives in the user-data directory, so a profile instance locks
`~/.codex-the-second/electron-user-data` while normal Codex has nothing to contend
with. Confirmed on disk — the `SingletonLock` symlinks name different PIDs:

```
~/.codex-the-second/electron-user-data/SingletonLock
~/Library/Application Support/Codex/SingletonLock
```

This also gives the correct relaunch behaviour for free: opening
`Codex the 2nd.app` while it is already running fails the lock, so Codex exits
0 and focuses the existing window instead of starting a third process.

Because that exit is a **successful** exit, the launcher's early-failure check
must not treat it as an error — it only reports a non-zero exit.

Related: [[profile-isolation-contract]], [[launch-without-launchservices]]
