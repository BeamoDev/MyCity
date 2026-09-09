"""Reject bare references to helpers/state moved into feature Context objects."""
from pathlib import Path
import re
from split_modules import TOKEN
root = Path(__file__).resolve().parents[1]
issues = []
for entry in (root / "src").rglob("init.luau"):
    header = entry.read_text(encoding="utf-8")
    if "local Context" not in header:
        continue
    files = list(entry.parent.glob("*.luau")) + list(entry.parent.glob("remotes/*.luau"))
    combined = "\n".join(p.read_text(encoding="utf-8") for p in files)
    names = set(re.findall(r"function Context\.(\w+)", combined)) | set(re.findall(r"State\.(\w+)\s*=", header))
    for path in files:
        if path == entry:
            continue
        source = path.read_text(encoding="utf-8")
        for match in TOKEN.finditer(source):
            before = source[:match.start()].rstrip()
            member = (before.endswith(".") and not before.endswith("..")) or before.endswith(":")
            if match[0] in names and not member:
                issues.append(f"{path.relative_to(root)}:{source.count(chr(10), 0, match.start())+1}: bare moved dependency {match[0]}")
for issue in issues:
    print(issue)
if issues:
    raise SystemExit(1)
print("PASS: extracted helpers and state are qualified, including concatenation and vararg boundaries")
