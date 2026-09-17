---
name: debug-a-failed-launch
description: What to check when Codex will not start, or starts on the wrong profile.
metadata:
  type: skill
---

**Why:** the launcher reports failures through a native alert, which is right
for users but hides the detail. Run the binary directly and the same message
goes to stderr, where it can be read and acted on.

**How to apply:**

```bash
# alerts off so nothing blocks on a modal dialog
export CODEX_THE_SECOND_NO_ALERTS=1
BIN="/Applications/Codex Personal.app/Contents/MacOS/CodexTheSecond"

"$BIN" --print-plan   # resolves everything, launches nothing
```

| Symptom | Cause | Fix |
| --- | --- | --- |
| "Codex could not be found" | Codex not installed, or somewhere unusual | pin the path (below) |
| Found the wrong app | another bundle matched first | pin the path |
| "This launcher is not configured correctly" | missing or invalid `profile.json` in the bundle | rebuild, or reinstall from the DMG |
| "would use the default Codex folder" | profile points at `~/.codex` | fix `codexHome`; see [[add-a-new-profile]] |
| Starts, then exits immediately | Codex rejected the launch options | check whether Codex changed; see [[upstream-behaviour-watch]] |
| Opens on the wrong account | `CODEX_HOME` overridden | check both variables are in `--print-plan` output |

Pin the Codex location, highest precedence first:

```bash
# one launch
CODEX_THE_SECOND_CODEX_APP="/path/to/Codex.app" "$BIN" --print-plan

# permanently
mkdir -p ~/Library/Application\ Support/CodexTheSecond
echo "/path/to/Codex.app" > ~/Library/Application\ Support/CodexTheSecond/codex-app-path
```

An explicitly configured path **fails loudly** rather than falling through to
the next candidate — a pinned path that is wrong is a mistake worth surfacing,
not routing around.

Check what is actually running, and with which profile:

```bash
ps -eo pid,ppid,command | grep "Contents/MacOS/ChatGPT" | grep -v grep
```

Related: [[codex-desktop-bundle]], [[verify-profile-isolation]]
