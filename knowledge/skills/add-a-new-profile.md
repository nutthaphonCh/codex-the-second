---
name: add-a-new-profile
description: Ship an additional launcher such as Codex Work.app by adding one JSON file.
metadata:
  type: skill
---

**Why:** profiles are configuration, not code. Anything that requires editing
Swift to add a second account has been designed wrong, and would need a review
and a release for what should be a one-file change.

**How to apply:**

1. Copy the example and edit it:

   ```bash
   cp profiles/work.json.example profiles/work.json
   ```

   ```json
   {
     "name": "Work",
     "slug": "work",
     "appName": "Codex Work",
     "bundleIdentifier": "com.local.codex-the-second.work",
     "codexHome": "~/.codex-work",
     "electronUserDataPath": "~/.codex-work/electron-user-data",
     "icon": { "label": "CW", "tintTop": "#2FB3A5", "tintBottom": "#0C3A36" }
   }
   ```

2. Build it:

   ```bash
   ./scripts/build.sh --profile work     # -> dist/Codex Work.app
   ```

3. Drag it into `/Applications` and sign in.

Rules the build and the launcher enforce for you:

- `slug` must be lowercase letters, digits and hyphens.
- `codexHome` must not be `~/.codex` or anything inside it — the launcher
  refuses to start rather than share the default profile.
- `bundleIdentifier` must be unique per profile, and must not start with
  `com.openai` (CI fails the build if it does).
- Give each profile its own icon colour and monogram; the whole point is telling
  them apart in the Dock.

CI builds every `profiles/*.json` on each push, so a broken profile fails there
rather than on someone's machine.

Related: [[profile-isolation-contract]], [[repository-map]]
