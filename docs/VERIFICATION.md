# Manual verification

Unit tests cover profile validation and launch-command construction. They cannot
prove that two Codex instances really are isolated — that needs the real
application. This is the procedure, and the results from the run that shipped
v0.2.0.

> **Do not paste tokens anywhere.** No step below needs to read `auth.json`, and
> `--print-plan` deliberately prints only `CODEX_HOME` and
> `CODEX_ELECTRON_USER_DATA_PATH`, never the inherited environment.

## 0. Preview the launch without launching

```bash
"/Applications/Codex Personal.app/Contents/MacOS/CodexTheSecond" --print-plan
```

Confirms which Codex was found and what would be passed to it:

```json
{
  "arguments": ["--user-data-dir=/Users/you/.codex-personal/electron-user-data"],
  "codexBundle": "/Applications/ChatGPT.app",
  "codexBundleIdentifier": "com.openai.codex",
  "codexVersion": "26.908.40834",
  "environment": {
    "CODEX_HOME": "/Users/you/.codex-personal",
    "CODEX_ELECTRON_USER_DATA_PATH": "/Users/you/.codex-personal/electron-user-data"
  },
  "executable": "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"
}
```

`codexBundle` being `ChatGPT.app` is expected: that is how Codex Desktop is
currently packaged. The `com.openai.codex` identifier is what confirms it.

## 1. Process isolation

Start normal Codex, then open `Codex Personal.app`, then:

```bash
ps -eo pid,ppid,command | grep "Contents/MacOS/ChatGPT" | grep -v grep
```

Expect two distinct main processes:

```
32810  1  /Applications/ChatGPT.app/Contents/MacOS/ChatGPT --user-data-dir=/Users/you/.codex-personal/electron-user-data
77419  1  /Applications/ChatGPT.app/Contents/MacOS/ChatGPT
```

Both have parent PID 1: the launcher spawns Codex and exits, so Codex is not a
child of the launcher and does not die with it.

## 2. Environment isolation

```bash
for pid in $(pgrep -f "^/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"); do
  echo "--- PID $pid ---"
  ps -E -o command= -p "$pid" | tr ' ' '\n' \
    | grep -E "^CODEX_HOME=|^CODEX_ELECTRON_USER_DATA_PATH=|^--user-data-dir=" \
    || echo "(no isolation vars -> default profile)"
done
```

Expect the profile instance to carry all three settings and normal Codex none:

```
--- PID 32810 ---
--user-data-dir=/Users/you/.codex-personal/electron-user-data
CODEX_HOME=/Users/you/.codex-personal
CODEX_ELECTRON_USER_DATA_PATH=/Users/you/.codex-personal/electron-user-data
--- PID 77419 ---
(no isolation vars -> default profile)
```

## 3. Filesystem isolation

```bash
ls ~/.codex-personal
ls ~/.codex-personal/electron-user-data/Default | grep -iE "cookies|local storage|session"
stat -f "%Sp %N" ~/.codex-personal ~/.codex-personal/electron-user-data
```

Expect a complete, separate profile — `config.toml`, `installation_id`, the
state/logs/memory SQLite databases — and a full Chromium profile beside it with
its own `Cookies`, `Local Storage` and `Session Storage`. Both directories should
be `drwx------`.

Confirm the instance locks are separate, which is why the two never collide:

```bash
ls -la ~/.codex-personal/electron-user-data/SingletonLock
ls -la ~/Library/Application\ Support/Codex/SingletonLock
```

They point at different PIDs.

Confirm your normal profile was not touched. Record this **before** first
launching the profile app and compare after:

```bash
stat -f "mtime=%m size=%z" ~/.codex/auth.json
```

It must be unchanged.

## 4. Authentication isolation

1. Sign normal Codex into account A.
2. Open `Codex Personal.app` and sign into account B.
3. Quit both.
4. Reopen both.

Each should come back signed into its own account. `~/.codex/auth.json` and
`~/.codex-personal/auth.json` are separate files; neither is read or written by
the other instance.

## 5. Relaunch behaviour

With `Codex Personal.app` already running, open it again. The existing profile
window should come forward and **no third process** should appear:

```bash
pgrep -fc "Contents/MacOS/ChatGPT"   # unchanged
```

This is Codex's own single-instance lock, scoped to the profile's user-data
directory.

## 6. Error handling

Alerts are suppressed here so the check cannot block on a modal dialog:

```bash
CODEX_THE_SECOND_NO_ALERTS=1 \
CODEX_THE_SECOND_CODEX_APP=/nonexistent/Codex.app \
  "/Applications/Codex Personal.app/Contents/MacOS/CodexTheSecond" --print-plan
```

Expect exit status 1 and a readable explanation. Run from Finder instead, the
same message appears as a native alert.

The safety rail that protects your normal profile:

```bash
python3 -c "import json;p=json.load(open('profiles/personal.json'));p['codexHome']='~/.codex';print(json.dumps(p))" > /tmp/bad.json
CODEX_THE_SECOND_NO_ALERTS=1 CODEX_THE_SECOND_PROFILE_FILE=/tmp/bad.json \
  "/Applications/Codex Personal.app/Contents/MacOS/CodexTheSecond" --print-plan
rm /tmp/bad.json
```

The launcher must refuse to run rather than share `~/.codex`.

## Results for v0.2.0

Verified on macOS 26.5.2 (Apple Silicon) against Codex Desktop 26.908.40834:

| Check | Result |
| --- | --- |
| Codex located without a hardcoded path | Pass — found `ChatGPT.app` by `com.openai.codex` |
| Two independent processes, both reparented to PID 1 | Pass |
| Isolation variables present on the profile instance only | Pass |
| Separate Codex home with its own config, state and logs | Pass |
| Separate Chromium profile: cookies, localStorage, session storage | Pass |
| Profile directories created `0700` | Pass |
| Per-profile `SingletonLock` | Pass |
| `~/.codex/auth.json` unchanged | Pass — identical mtime and size |
| Relaunch focuses the existing instance, no duplicate | Pass |
| Missing Codex reported, exit 1 | Pass |
| Profile pointed at `~/.codex` refused | Pass |
| Two accounts signed in independently | Pass - separate `auth.json`, both `0600` |
| `~/.codex/auth.json` untouched by the second profile | Pass - unchanged since before the profile existed |

Step 4 was confirmed with two real accounts: `~/.codex/auth.json` and
`~/.codex-personal/auth.json` are different files with different contents, and
the default one was last written before the second profile existed. Neither file
was read or printed during verification.
