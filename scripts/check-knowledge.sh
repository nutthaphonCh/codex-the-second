#!/usr/bin/env bash
# Validates the knowledge base, and the links CLAUDE.md makes into it.
#
# Checks that every entry has well-formed frontmatter, that its name matches its
# filename, that every [[wiki-link]] resolves, that every entry is routed from the route table, and
# that relative links point at files that exist.
#
# Run by CI so the knowledge base cannot rot silently.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 - <<'PY'
import pathlib, re, sys

root = pathlib.Path("knowledge")
index = root / "README.md"
failures = []

entries = sorted(p for p in root.rglob("*.md") if p.name != "README.md")
if not entries:
    print("no knowledge entries found"); sys.exit(1)

names = {}
FRONTMATTER = re.compile(
    r"\A---\nname: (?P<name>[a-z0-9-]+)\n"
    r"description: (?P<description>.+)\n"
    r"metadata:\n  type: (?P<type>wiki|skill|reference)\n---\n",
)

for path in entries:
    text = path.read_text()
    match = FRONTMATTER.match(text)
    if not match:
        failures.append(f"{path}: frontmatter missing or malformed")
        continue

    name, description, kind = match["name"], match["description"], match["type"]
    names[name] = path

    if name != path.stem:
        failures.append(f"{path}: name '{name}' does not match the filename")
    if kind != path.parent.name.rstrip("s") and not (kind == "wiki" and path.parent.name == "wiki"):
        failures.append(f"{path}: type '{kind}' does not match folder '{path.parent.name}'")
    if len(description) > 160:
        failures.append(f"{path}: description is {len(description)} chars; keep it to one line")
    if kind == "skill":
        for required in ("**Why:**", "**How to apply:**"):
            if required not in text:
                failures.append(f"{path}: a skill entry must include {required}")

# [[wiki-links]] must resolve to a real entry
for path in entries:
    for link in re.findall(r"\[\[([a-z0-9-]+)\]\]", path.read_text()):
        if link not in names:
            failures.append(f"{path}: [[{link}]] does not resolve to an entry")

# every entry must be reachable from the route table
index_text = index.read_text()
for name, path in sorted(names.items()):
    if str(path.relative_to(root)) not in index_text:
        failures.append(f"{path}: not routed from the route table in knowledge/README.md")

# CLAUDE.md points into knowledge/ heavily; those links must not rot either
claude_md = pathlib.Path("CLAUDE.md")
checked = [index, *entries]
if claude_md.exists():
    checked.append(claude_md)
else:
    failures.append("CLAUDE.md is missing")

# relative markdown links must point at files that exist
for path in checked:
    for target in re.findall(r"\]\((?!https?://|#)([^)]+)\)", path.read_text()):
        target = target.split("#")[0]
        if target and not (path.parent / target).resolve().exists():
            failures.append(f"{path}: broken link -> {target}")

if failures:
    print("Knowledge base problems:")
    for failure in failures:
        print(f"  FAIL  {failure}")
    sys.exit(1)

print(f"  ok    {len(entries)} entries, frontmatter valid")
print(f"  ok    all [[wiki-links]] resolve")
print(f"  ok    all entries routed from knowledge/README.md")
print(f"  ok    all relative links resolve, CLAUDE.md included")
PY
