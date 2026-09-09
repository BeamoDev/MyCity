"""Check literal require paths against the Script Sync instance tree.

Does not execute Luau. Dynamic requires and Studio-only dependencies are reported
separately; passing this check does not prove the place contains authored assets.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MAPPINGS = {
    "server": ("ServerScriptService", "server"),
    "client": ("StarterPlayer", "StarterPlayerScripts", "client"),
    "shared": ("ReplicatedStorage", "shared"),
}
SUFFIXES = (".legacy.luau", ".local.luau", ".server.luau", ".client.luau", ".luau")


def instance_path(path):
    parts = path.relative_to(ROOT / "src").parts
    name = next(parts[-1][:-len(s)] for s in SUFFIXES if parts[-1].endswith(s))
    return MAPPINGS[parts[0]] + parts[1:-1] + (() if name == "init" else (name,))


def strip_comments(source):
    # Preserve quoted strings and newlines so diagnostics retain source line numbers.
    pattern = r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    return re.sub(pattern, lambda m: "\n" * m[0].count("\n") if m[0].startswith("--") else m[0], source)


files = sorted((ROOT / "src").rglob("*.luau"))
instances = {instance_path(p): p for p in files}
module_paths = {key for key, p in instances.items() if p.name.endswith(".luau")
                and not p.name.endswith(SUFFIXES[:-1])}
checked, external, dynamic, failures = 0, set(), set(), []
segment = r'(?:\.[A-Za-z_]\w*|:(?:WaitForChild|FindFirstChild)\(\s*"[^"]+"(?:\s*,\s*\d+)?\s*\))'
literal_require = re.compile(r'\brequire\(\s*(script|ReplicatedStorage|shared|game:GetService\("(?:ReplicatedStorage|ServerScriptService)"\))(' + segment + r'*)\s*\)')
for path in files:
    source = strip_comments(path.read_text(encoding="utf-8-sig"))
    matches = list(literal_require.finditer(source))
    matched_starts = {m.start() for m in matches}
    for m in re.finditer(r'\brequire\(', source):
        if m.start() not in matched_starts:
            dynamic.add(f"{path.relative_to(ROOT)}:{source[:m.start()].count(chr(10)) + 1}")
    for m in matches:
        target = list(instance_path(path) if m[1] == "script" else
                      MAPPINGS["shared"] if m[1] == "shared" else ("ServerScriptService",) if "ServerScriptService" in m[1] else ("ReplicatedStorage",))
        for part in re.finditer(r'\.([A-Za-z_]\w*)|:(?:WaitForChild|FindFirstChild)\(\s*"([^"]+)"(?:\s*,\s*\d+)?\s*\)', m[2]):
            name = part[1] or part[2]
            if name == "Parent" and part[1]:
                target.pop()
            else:
                target.append(name)
        key = tuple(target)
        if key in module_paths:
            checked += 1
        elif key[:2] == ("ReplicatedStorage", "TopbarPlus"):
            external.add(".".join(key))
        else:
            failures.append(f"{path.relative_to(ROOT)}:{source[:m.start()].count(chr(10)) + 1}: missing ModuleScript {'.'.join(key)}")
    for stale in ("ReplicatedStorage.Client", "Workspace.Map.Plots", "workspace.Map.Plots", "Workspace.Map:WaitForChild(\"Plots\")", "ReplicatedStorage.Assets.Buildings", "NotificationsFrame", "Events.BuilderLimitReached",
                  "ReplicatedStorage.Expansion", "ReplicatedStorage.Modules.UIEffects"):
        if stale in source:
            failures.append(f"{path.relative_to(ROOT)}: stale path {stale}")

for failure in failures:
    print("FAIL:", failure)
print(f"{len(files)} files; {checked} resolved local requires; {len(external)} Studio-only require targets; {len(dynamic)} dynamic requires")
for value in sorted(external):
    print("STUDIO:", value)
for value in sorted(dynamic):
    print("DYNAMIC (manual review):", value)
if failures:
    raise SystemExit(1)
print("PASS: literal source module paths resolve under the configured mappings")
