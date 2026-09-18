# Verification

What has actually been checked against the real Codex Desktop application, how,
and — just as importantly — what has **not**.

Unit tests cover launch-plan construction and the isolation guard. They cannot
show that two running Codex instances are separate. Only the real application
can, so this record exists and is kept honest.

## Evidence levels

Claims below are labelled, and the labels are meant literally.

| Label | Meaning |
| --- | --- |
| **Verified** | Directly executed and the output inspected. Reproducible with the commands in this document. |
| **Observed** | Seen to be true on a real system, but as a state rather than a controlled experiment. |
| **Inferred** | Follows from Verified facts plus how Codex is known to behave. Not directly exercised. Treat as implementation-dependent. |
| **Not tested** | Not attempted. Stated so nobody assumes otherwise. |

Nothing inferred is described as verified.

## Test subject

| | |
| --- | --- |
| Launcher version | 0.3.0 |
| Codex Desktop | 26.908.40834 (`com.openai.codex`, installed as `/Applications/ChatGPT.app`) |
| macOS | 26.5.2, Apple Silicon (arm64) |
| Default profile path | `~/.codex` |
| Secondary profile path | `~/.codex-the-second` |
| Secondary Electron user data | `~/.codex-the-second/electron-user-data` |
| Date | 2026-09-17 |

The authoritative copy of the Codex build is [`tested-with.json`](../tested-with.json),
which is published in every release; CI fails if this document disagrees with it.

## Results

| # | Claim | Level |
| --- | --- | --- |
| 1 | Codex is located without a hardcoded path — resolved `/Applications/ChatGPT.app` by identifier, executable read from `Info.plist` | **Verified** |
| 2 | Two Codex processes run at once, each reparented to PID 1 | **Verified** |
| 3 | The isolation variables are present on the profile process and absent on the default one, read from the **running process**, not from the launch plan | **Verified** |
| 4 | The secondary profile has its own Codex home — config, state, logs, SQLite stores | **Verified** |
| 5 | The secondary profile has its own Chromium profile — Cookies, Local Storage, Session Storage | **Verified** |
| 6 | Profile directories are created `0700` | **Verified** |
| 7 | Each instance holds its own Electron `SingletonLock`, naming different PIDs | **Verified** |
| 8 | `~/.codex/auth.json` is unchanged by running the secondary profile — identical size and mtime before and after | **Verified** |
| 9 | Relaunching the profile app focuses the running instance instead of starting a third | **Verified** |
| 10 | A missing or unusable Codex exits non-zero with an explanation rather than failing silently | **Verified** |
| 11 | A profile configured at `~/.codex` is refused before launch | **Verified** |
| 12 | A profile that reaches `~/.codex` through a **symlink** or a different **letter case** is refused before launch | **Verified** |
| 13 | The two instances are signed into different accounts — `~/.codex/auth.json` and `~/.codex-the-second/auth.json` are both `0600`, differ in content, and were last written 2 days apart | **Observed** |
| 14 | Each profile keeps its session across a restart | **Inferred** — the session state lives under the isolated path, and Codex reads it from there; not exercised as a restart cycle |
| 15 | Both accounts remain logged in after restarting **both** instances | **Not tested** — see below |

### Why #15 was not tested

It requires quitting the user's running Codex instances, which is not something
this record's author could do to someone else's session. The sign-ins in #13
were performed by the account owner, not by the author.

To check it yourself: quit both applications, reopen both, and confirm each
returns to its own account. If you do, the result belongs in this table.

## Procedure

Alerts are suppressed so a failure path cannot block on a modal dialog:

```bash
export CODEX_THE_SECOND_NO_ALERTS=1
BIN="/Applications/Codex the 2nd.app/Contents/MacOS/CodexTheSecond"
```

**Resolution, without launching** — covers #1:

```bash
"$BIN" --print-plan
```

Prints the bundle it found, its identifier and version, the executable, and the
two isolation variables. It deliberately prints **nothing else from the
environment**; a unit test asserts that, so this is safe to paste into an issue.

**Process isolation** — covers #2:

```bash
ps -eo pid,ppid,command | grep "Contents/MacOS/ChatGPT" | grep -v grep
```

```
32810  1  .../MacOS/ChatGPT --user-data-dir=/Users/you/.codex-personal/electron-user-data
77419  1  .../MacOS/ChatGPT
```

Both show PPID 1: the launcher spawns Codex and exits, so Codex is not a child
of the launcher and does not die with it.

**Environment isolation** — covers #3. Read from the running process rather than
from the plan, because the plan states intent and this states fact:

```bash
for pid in $(pgrep -f "^/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"); do
  echo "PID $pid:"
  ps -E -o command= -p "$pid" | tr ' ' '\n' \
    | grep -E "^CODEX_HOME=|^CODEX_ELECTRON_USER_DATA_PATH="
done
```

```
PID 32810:
  CODEX_HOME=/Users/you/.codex-personal
  CODEX_ELECTRON_USER_DATA_PATH=/Users/you/.codex-personal/electron-user-data
PID 77419:
  (nothing — default profile)
```

**Filesystem separation** — covers #4, #5, #6, #7:

```bash
du -sh ~/.codex ~/.codex-the-second
stat -f "%Sp %N" ~/.codex-the-second ~/.codex-the-second/electron-user-data
ls ~/.codex-the-second/electron-user-data/Default | grep -iE "cookies|local storage|session"
ls -la ~/.codex-the-second/electron-user-data/SingletonLock
ls -la ~/Library/Application\ Support/Codex/SingletonLock
```

Observed: 3.1G against 651M, both directories `drwx------`, four separate web
storage entries, and two `SingletonLock` symlinks naming different PIDs.

**The default profile is untouched** — covers #8. Record before the first launch
of the profile app and compare afterwards:

```bash
stat -f "mtime=%m size=%z" ~/.codex/auth.json
```

**Authentication** — covers #13. **Never print token contents.** Compare
metadata only:

```bash
cmp -s ~/.codex/auth.json ~/.codex-the-second/auth.json \
  && echo "same — not isolated" || echo "different — isolated"
stat -f "%Sp %N" ~/.codex/auth.json ~/.codex-the-second/auth.json
```

**Failure paths** — covers #10, #11, #12:

```bash
# Codex pinned somewhere it is not
CODEX_THE_SECOND_CODEX_APP=/nonexistent/Codex.app "$BIN" --print-plan; echo "exit=$?"

# a profile pointed straight at the default
python3 -c "import json;p=json.load(open('profiles/2nd.json'));p['codexHome']='~/.codex';print(json.dumps(p))" > /tmp/bad.json
CODEX_THE_SECOND_PROFILE_FILE=/tmp/bad.json "$BIN" --print-plan; echo "exit=$?"

# a profile that only looks separate: a symlink back to the default
ln -s ~/.codex /tmp/looks-separate
python3 -c "import json,sys;p=json.load(open('profiles/2nd.json'));p['codexHome']='/tmp/looks-separate';p['electronUserDataPath']='/tmp/looks-separate/electron-user-data';print(json.dumps(p))" > /tmp/link.json
CODEX_THE_SECOND_PROFILE_FILE=/tmp/link.json "$BIN" --print-plan; echo "exit=$?"
rm /tmp/bad.json /tmp/link.json /tmp/looks-separate
```

All three must exit `1` with an explanation. The third is the one that matters
most: before v0.3.0 it exited `0` and would have started the secondary launcher
against the primary profile.

## What this is not

The launcher redirects **where Codex stores a profile**. That is the whole of
it, and the words below are chosen deliberately.

It provides an **isolated profile** — a separate profile namespace, a separate
Electron user-data directory, separate session and authentication state.

It is **not** a security sandbox, a filesystem sandbox, a container, process
confinement, or anything VM-like. The spawned Codex:

- runs as the **same macOS user**, with that user's full permissions
- can read and write **anything outside** the redirected profile locations,
  including `~/.codex`, if it or something it runs chooses to
- is the **same binary**, with the same entitlements, as your normal Codex

The isolation is a matter of configuration, not enforcement. It separates two
accounts from each other; it does not contain either of them.

## Limits of this record

- One machine, one Codex build, one macOS version. See the table above.
- Codex's handling of these variables is not a public API. What is verified here
  is verified for that build; see
  [upstream behaviour watch](../knowledge/reference/upstream-behaviour-watch.md)
  for what to re-check after a Codex update, and which failures would be silent.
- #14 and #15 remain open. They are the two claims a user can most easily close
  themselves.
