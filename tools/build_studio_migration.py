"""Build the edit-mode migration from the reviewed source move manifest."""
from pathlib import Path
import json,re

ROOT=Path(__file__).resolve().parents[1]
mapping=json.loads((ROOT/'docs/layout-migration.json').read_text(encoding='utf-8'))
def parts(rel):
    values=rel.split('/')
    name=re.sub(r'(?:\.legacy|\.local)?\.luau$','',values[-1])
    return values[:-1]+([] if name=='init' else [name])
def lua_array(values):return '{ '+', '.join(json.dumps(v) for v in values)+' }'
entries=[]
for old,new in sorted(mapping.items(),key=lambda item:len(parts(item[0])),reverse=True):
    if old=='server/Main/init.legacy.luau':continue # Keep the existing Main entry point; Items is now in ReplicatedStorage.Assets.
    entries.append('\t{ '+lua_array(parts(old))+', '+lua_array(parts(new))+' },')
types=[]
for path in sorted((ROOT/'src').rglob('*.luau')):
    rel=path.relative_to(ROOT/'src').as_posix()
    kind='LocalScript' if '.local.luau' in rel else 'Script' if '.legacy.luau' in rel else 'ModuleScript'
    types.append('\t["'+'.'.join(parts(rel))+'"] = "'+kind+'",')
script='''-- Run ONCE in Studio Command Bar in EDIT mode, with Script Sync paused.
-- Moves existing templates with their modules. Resume source sync before Play.
-- Old replaced scripts are disabled and archived; no gameplay/DataStore calls.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before migrating")
local moves = {
'''+ '\n'.join(entries)+'''
}
local classes = {
'''+ '\n'.join(types)+'''
}
local starter = game:GetService("StarterPlayer").StarterPlayerScripts
local roots = {
 server = game:GetService("ServerScriptService"):FindFirstChild("server"),
 client = starter:FindFirstChild("client") or starter,
 shared = game:GetService("ReplicatedStorage"):FindFirstChild("shared"),
}
assert(roots.server and roots.shared, "Expected server and shared Script Sync roots")
local function resolve(path, create, stopBeforeLeaf)
 local current = roots[path[1]]
 local prefix = path[1]
 local last = #path - (stopBeforeLeaf and 1 or 0)
 for index = 2, last do
  local name = path[index]
  prefix ..= "." .. name
  local child = current:FindFirstChild(name)
  if not child and create then
   child = Instance.new(classes[prefix] or "Folder")
   child.Name = name
   child.Parent = current
  end
  if not child then return nil end
  current = child
 end
 return current
end

-- Preflight destination classes, including parent ModuleScripts, before mutation.
for path, expected in classes do
 local names = string.split(path, ".")
 local current = roots[names[1]]
 local prefix = names[1]
 for index = 2, #names do
  prefix ..= "." .. names[index]
  current = current and current:FindFirstChild(names[index])
  if not current then break end
  local kind = classes[prefix] or "Folder"
  assert(current.ClassName == kind, "Wrong destination class: " .. current:GetFullName() .. "; expected " .. kind)
 end
end

-- Preflight authored child collisions before moving anything.
for _, move in moves do
 local old, target = resolve(move[1]), resolve(move[2])
 if old and target and old ~= target then
  for _, child in old:GetChildren() do
   if target:FindFirstChild(child.Name) then
    error("Template collision; preserve and reconcile both copies: " .. target:GetFullName() .. "." .. child.Name)
   end
  end
 end
end

game:GetService("ChangeHistoryService"):SetWaypoint("Before MyCity folder migration")
local storage = game:GetService("ServerStorage")
local archive = storage:FindFirstChild("MyCityMigrationArchive") or Instance.new("Folder")
archive.Name = "MyCityMigrationArchive"
archive.Parent = storage
local count = 0
for _, move in moves do
 local old = resolve(move[1])
 if not old then continue end
 local parent = resolve(move[2],true,true)
 local name = move[2][#move[2]]
 local target = parent:FindFirstChild(name)
 local expected = classes[table.concat(move[2],".")]
 if old == target then continue end
 if not target and old.ClassName == expected then
  old.Name = name
  old.Parent = parent
 else
  if not target then
   target = Instance.new(expected)
   target.Name = name
   target.Parent = parent
  end
  assert(target.ClassName == expected,"Wrong destination class: " .. target:GetFullName())
  for _, child in old:GetChildren() do
   assert(not target:FindFirstChild(child.Name),"Conflicting child: " .. child.Name)
   child.Parent = target
  end
  if old:IsA("BaseScript") then old.Enabled = false end
  old.Name = table.concat(move[1],"_")
  old.Parent = archive
 end
 count += 1
end
game:GetService("ChangeHistoryService"):SetWaypoint("After MyCity folder migration")
print("[MyCity] Moved",count,"source containers. Resume Script Sync and sync all src files before Play.")
print("[MyCity] Items belongs under ReplicatedStorage.Assets.Items. Archived scripts are disabled in ServerStorage.")
'''
(ROOT/'tools/migrate_studio.luau').write_text(script,encoding='utf-8')
print('Generated edit-mode asset-preserving Studio migration')
