---
name: launch-without-launchservices
description: Codex is spawned as a direct child process because open/LaunchServices can route the request into an already-running instance.
metadata:
  type: wiki
---

The launcher never runs `open -a Codex`.

Two reasons:

1. **Routing.** LaunchServices can hand the request to an already-running Codex,
   which then ignores the profile entirely — the user gets a second window on
   the *wrong* account, which is worse than an error.
2. **Ordering.** The isolated environment has to exist before Electron
   initialises. A direct `Process` spawn guarantees that; anything that asks
   another process to do the launching does not.

`open -n --env ... --args ...` would avoid the routing problem, and Codex's own
internal profile launcher uses exactly that. A direct spawn was still preferred:
it is fewer moving parts and makes the environment unambiguous.

Consequences worth knowing:

- The spawned Codex is reparented to PID 1 once the launcher exits, so it does
  **not** die with the launcher. Verified: both instances show `PPID 1`.
- The launcher waits ~1.5 s before exiting, purely so an immediate crash can be
  reported instead of appearing to do nothing. A clean exit 0 in that window is
  success, not failure — see [[single-instance-locking]].
- While running, the process is Codex, so the Dock shows Codex's identity. The
  distinct launcher icon identifies the launcher, not the running window.

Related: [[profile-isolation-contract]], [[codex-desktop-bundle]]
