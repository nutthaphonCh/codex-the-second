---
name: verify-profile-isolation
description: Prove two Codex instances are genuinely separate, without ever reading an auth token.
metadata:
  type: skill
---

**Why:** unit tests cover how the launch command is built, which is not the same
as proving the running applications are isolated. Only the real app can show
that, and a regression here means someone's account data leaks into the wrong
profile.

**How to apply:** the full procedure with expected output is
[docs/verification.md](../../docs/verification.md). The short form:

```bash
# 1. what would be launched, without launching
"/Applications/Codex Personal.app/Contents/MacOS/CodexTheSecond" --print-plan

# 2. two distinct processes, both reparented to PID 1
ps -eo pid,ppid,command | grep "Contents/MacOS/ChatGPT" | grep -v grep

# 3. isolation variables on the profile instance only
for pid in $(pgrep -f "^/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"); do
  ps -E -o command= -p "$pid" | tr ' ' '\n' \
    | grep -E "^CODEX_HOME=|^CODEX_ELECTRON_USER_DATA_PATH=" || echo "(default profile)"
done

# 4. separate Chromium state, and separate instance locks
ls ~/.codex-personal/electron-user-data/Default | grep -iE "cookies|local storage|session"
ls -la ~/.codex-personal/electron-user-data/SingletonLock
```

**Never print token contents.** `--print-plan` deliberately emits only
`CODEX_HOME` and `CODEX_ELECTRON_USER_DATA_PATH`, never the inherited
environment — a unit test asserts that. To check authentication isolation,
compare metadata only:

```bash
cmp -s ~/.codex/auth.json ~/.codex-personal/auth.json \
  && echo "SAME - not isolated" || echo "different - isolated"
stat -f "%Sp %z %N" ~/.codex/auth.json ~/.codex-personal/auth.json
```

Both should be `-rw-------`. Record `~/.codex/auth.json`'s mtime before first
launching a profile; it must be unchanged afterwards.

Related: [[single-instance-locking]], [[profile-isolation-contract]]
