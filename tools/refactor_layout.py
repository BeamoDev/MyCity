"""One-time source layout migration. Runtime code never imports this tool."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
mapping = {}
server_groups = {
    "systems/building": ["BuildingSystem"],
    "systems/construction": ["ConstructionSystem"],
    "systems/economy": ["IncomeSystem", "InventorySystem", "SellSystem", "ShopSystem"],
    "systems/progression": ["RebirthSystem", "RebirthConfig", "DailyRewards", "PostTutorialQuest", "TutorialSystem", "BadgeModule"],
    "systems/world": ["PlotManager", "ExpansionSystem", "CityNameSystem", "HighwayTrafficSystem", "TrainSystem", "WeatherSystem", "VFX"],
    "persistence": ["PlayerDataModule", "FunnelAnalytics"],
    "services": ["MarketPlaceHandler", "ToolSetup", "CodeSystem"],
    "config": ["BuildingConfig", "SpawnConfig"],
}
for path in (SRC / "server/Main").rglob("*.luau"):
    rel = path.relative_to(SRC).as_posix()
    sub = path.relative_to(SRC / "server/Main").as_posix()
    first = sub.split("/")[0].removesuffix(".luau")
    if sub == "init.legacy.luau":
        dest = "server/bootstrap/ServerBootstrap.luau"
    elif sub == "DeleteDatastore.legacy.luau":
        dest = "server/maintenance/DeleteDatastore.luau"
    else:
        group = next(group for group, names in server_groups.items() if first in names)
        dest = "server/" + group + "/" + sub
    mapping[rel] = dest
for name in ["CityRating", "FriendBoost"]:
    mapping[f"server/{name}.legacy.luau"] = f"server/systems/social/{name}.luau"
controllers = {
    "Init": "bootstrap/HudBootstrap",
    "UIController": "controllers/ui/UIController",
    "NotificationController": "controllers/ui/NotificationController",
    "ShopController": "controllers/shop/ShopController",
    "SellController": "controllers/shop/SellController",
    "TutorialController": "controllers/tutorial/TutorialController",
    "ToolsModule": "controllers/placement/ToolsModule",
    "FriendsBoost": "controllers/social/FriendsBoost",
    "LikeSystem": "controllers/social/LikeSystem",
}
for name, dest in controllers.items():
    mapping[f"shared/{name}.luau"] = f"client/{dest}.luau"
for name, dest in {
    "BuildingTools": "placement/BuildingTools", "ChatTags": "social/ChatTags",
    "ExpandHighlight": "placement/ExpandHighlight", "Functions": "systems/ResetButton",
    "ProximityPromptScript": "ui/ProximityPromptController",
}.items():
    mapping[f"client/{name}.local.luau"] = f"client/controllers/{dest}.luau"

roots = {"server": ("ServerScriptService", "server"), "client": ("StarterPlayer", "StarterPlayerScripts", "client"), "shared": ("ReplicatedStorage", "shared")}
def instance_path(rel):
    parts = rel.split("/")
    name = re.sub(r"(?:\.legacy|\.local)?\.luau$", "", parts[-1])
    return roots[parts[0]] + tuple(parts[1:-1]) + (() if name == "init" else (name,))

paths = {instance_path(a): instance_path(b) for a,b in mapping.items()}
paths[("ServerScriptService", "server", "Main", "Items")] = ("ServerScriptService", "server", "Main", "Items")
def remap(target):
    for prefix in sorted(paths, key=len, reverse=True):
        if target[:len(prefix)] == prefix:
            return paths[prefix] + target[len(prefix):]
    return target

segment = r'(?:\.[A-Za-z_]\w*|:(?:WaitForChild|FindFirstChild)\(\s*"[^"]+"(?:\s*,\s*\d+)?\s*\))'
chain = re.compile(r'\b(script|ReplicatedStorage|shared)(' + segment + r'+)')
parts_pattern = re.compile(r'\.([A-Za-z_]\w*)|:(?:WaitForChild|FindFirstChild)\(\s*"([^"]+)"(?:\s*,\s*\d+)?\s*\)')

def reference(target, current):
    common = 0
    while common < min(len(target), len(current)) and target[common] == current[common]: common += 1
    if common >= 2:
        value = "script" + ".Parent" * (len(current)-common)
        names = target[common:]
    else:
        value = f'game:GetService("{target[0]}")'
        names = target[1:]
    # WaitForChild makes moved client dependencies safe during replication.
    return value + ''.join(f':WaitForChild("{name}")' for name in names)

def rewrite(source, old, new):
    def replace(match):
        target = list(instance_path(old) if match[1] == "script" else roots["shared"] if match[1] == "shared" else ("ReplicatedStorage",))
        for part in parts_pattern.finditer(match[2]):
            name = part[1] or part[2]
            if name == "Parent" and part[1]: target.pop()
            else: target.append(name)
        target = tuple(target)
        updated = remap(target)
        if match[1] != "script" and updated == target: return match[0]
        return reference(updated, instance_path(new))
    # Leave comments and quoted text untouched; transform only code spans.
    literal = re.compile(r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
    # Match whole instance expressions first, so quoted WaitForChild arguments remain part of them.
    combined = re.compile(chain.pattern + "|" + literal.pattern.replace(r'\1', r'\3'))
    return combined.sub(lambda m: replace(m) if m[1] else m[0], source)

if __name__ == "__main__":
    assert (SRC / "server/Main/init.legacy.luau").exists(), "Layout migration already applied"
    for old, new in mapping.items():
        target = (SRC/new).resolve()
        assert target.is_relative_to(SRC.resolve()) and not target.exists(), new
    changes = {}
    for p in SRC.rglob("*.luau"):
        old = p.relative_to(SRC).as_posix(); new = mapping.get(old,old)
        if old.endswith("WebHook.luau"):
            changes[new] = p.read_text(encoding="utf-8")
            continue
        changes[new] = rewrite(p.read_text(encoding="utf-8"),old,new)
    for old,new in mapping.items():
        p=SRC/new;p.parent.mkdir(parents=True,exist_ok=True)
        (SRC/old).rename(p)
    for rel,source in changes.items(): (SRC/rel).write_text(source,encoding="utf-8")
    (ROOT/"docs/layout-migration.json").write_text(json.dumps(mapping,indent=2)+"\n",encoding="utf-8")
    print(f"Moved and rewired {len(mapping)} source files")
