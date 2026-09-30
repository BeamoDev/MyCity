-- Renders the MilitaryBase helicopter locally. The authoritative placed building remains
-- stationary, so cosmetic flight never creates server replication or affects saving.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local Controller = {}
local BUILDING_TYPE = "MilitaryBase"
local HELI_NAME = "Heli"
local MAIN_BLADE_NAMES = { "MainBlades", "main top_Material.016_0.002" }
local REAR_ROTOR_NAMES = { "RearRotor", "main top_Material.016_0.011" }
local DEFAULT_RADIUS = 9
local MINIMUM_HEIGHT = 8
local DEFAULT_ORBIT_SPEED = 0.88 / 3
local DEFAULT_BLADE_SPEED = math.rad(900)
local DEFAULT_YAW = math.rad(90)

local started = false
local readyConnection
local elapsed = 0
local entries = {}
local connections = {}
local animationFolder
local warned = {}

local function warnOnce(key, message)
	if not warned[key] then
		warned[key] = true
		warn("[MilitaryHelicopter] " .. message)
	end
end

local function numberAttribute(primary, fallback, name, default)
	local value = primary and primary:GetAttribute(name)
	if typeof(value) ~= "number" and fallback then
		value = fallback:GetAttribute(name)
	end
	return if typeof(value) == "number" then value else default
end

local function phaseFor(value)
	local hash = 0
	for index = 1, #value do
		hash = (hash * 33 + string.byte(value, index)) % 1000003
	end
	return (hash % 3600) / 3600 * math.pi * 2
end

local function pathPoint(center, angle, radius, height, pathPhase)
	-- Slow harmonics smoothly vary the radius and altitude, producing closer low/high passes
	-- without abrupt random direction changes. The path remains inside the authored radius.
	local radial = radius
		* (0.55 + 0.20 * math.sin(angle * 0.43 + pathPhase) + 0.12 * math.sin(angle * 0.91 - pathPhase))
	local wander = radius * 0.05
	local altitude = height
		+ 1.75 * math.sin(angle * 0.37 + pathPhase)
		+ 0.75 * math.sin(angle * 0.83 - pathPhase)
	return center
		+ Vector3.new(
			math.cos(angle) * radial + math.sin(angle * 2.3 + pathPhase) * wander,
			altitude,
			math.sin(angle) * radial + math.cos(angle * 1.9 - pathPhase) * wander
		)
end

local function flightFrame(center, angle, radius, height, yaw, pathPhase)
	pathPhase = pathPhase or 0
	local position = pathPoint(center, angle, radius, height, pathPhase)
	local ahead = pathPoint(center, angle + 0.01, radius, height, pathPhase)
	local tangent = (ahead - position).Unit
	local pitch = math.rad(4) * math.sin(angle * 2.3 + pathPhase)
	local inwardBank = math.rad(-10 + 5 * math.sin(angle * 1.7 - pathPhase))
	return CFrame.lookAt(position, position + tangent, Vector3.yAxis)
		* CFrame.Angles(pitch, yaw, inwardBank)
end

-- Kept visible for the local regression test; runtime uses these same calculations.
Controller.phaseFor = phaseFor
Controller.flightFrame = flightFrame

local function findBlade(heli, names)
	for _, name in names do
		local blade = heli:FindFirstChild(name, true)
		if blade and blade:IsA("BasePart") then
			return blade
		end
	end
	return nil
end

local function militaryBuilding(item)
	local current = item
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("BuildingType") == BUILDING_TYPE then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function cleanClone(clone)
	for _, item in clone:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = true
			-- LocalTransparencyModifier can be inherited by a clone made from a locally hidden source.
			item.LocalTransparencyModifier = 0
		elseif item:IsA("WeldConstraint")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
			or item:IsA("Script")
			or item:IsA("LocalScript")
			or item:IsA("ModuleScript")
			or item:IsA("ProximityPrompt")
			or item:IsA("ClickDetector")
		then
			item:Destroy()
		end
	end
end

local function restore(entry)
	if entry.clone then
		entry.clone:Destroy()
	end
	for part, transparency in entry.hidden do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	entries[entry.building] = nil
end

local function add(building)
	if entries[building]
		or not building:IsA("Model")
		or building:GetAttribute("BuildingType") ~= BUILDING_TYPE
	then
		return
	end
	local base = building:FindFirstChild("Base")
	local original = building:FindFirstChild(HELI_NAME)
	if not (base and base:IsA("BasePart") and original and original:IsA("Model")) then
		-- A placed Model can replicate before its descendants. DescendantAdded retries its owner.
		return
	end
	if not findBlade(original, MAIN_BLADE_NAMES) or not findBlade(original, REAR_ROTOR_NAMES) then
		-- Wait for both authored blade MeshParts before cloning a complete helicopter.
		return
	end

	local ok, clone = pcall(function()
		return original:Clone()
	end)
	if not ok or not clone then
		warnOnce("clone", "Could not clone the authored MilitaryBase.Heli model")
		return
	end
	cleanClone(clone)
	local pivot = clone:GetPivot()
	local parts = {}
	for _, item in clone:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, { part = item, relative = pivot:ToObjectSpace(item.CFrame) })
		end
	end
	if #parts == 0 then
		clone:Destroy()
		warnOnce("parts", "MilitaryBase.Heli has no BaseParts to animate")
		return
	end

	local bladeY, bladeZ = findBlade(clone, MAIN_BLADE_NAMES), findBlade(clone, REAR_ROTOR_NAMES)
	if not bladeY then
		warnOnce("MainBlades", "Missing Heli.MainBlades")
	end
	if not bladeZ then
		warnOnce("RearRotor", "Missing Heli.RearRotor")
	end
	local hidden = {}
	local authoredHeight = math.max(original:GetPivot().Position.Y - base.Position.Y - 2, MINIMUM_HEIGHT)
	for _, item in original:GetDescendants() do
		if item:IsA("BasePart") then
			hidden[item] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		end
	end
	clone.Name = "MilitaryHeli_" .. tostring(building:GetAttribute("BuildingID") or building.Name)
	clone.Parent = animationFolder
	entries[building] = {
		building = building,
		base = base,
		original = original,
		clone = clone,
		parts = parts,
		bladeY = bladeY,
		bladeZ = bladeZ,
		hidden = hidden,
		phase = phaseFor(tostring(building:GetAttribute("BuildingID") or building:GetFullName())),
		pathPhase = phaseFor(tostring(building:GetAttribute("BuildingID") or building:GetFullName()) .. ":path"),
		authoredHeight = authoredHeight,
	}
end

local function update(deltaTime)
	elapsed += deltaTime
	for building, entry in entries do
		if not building:IsDescendantOf(Workspace) or not entry.base:IsDescendantOf(building) then
			restore(entry)
			continue
		end
		local radius = math.max(1, numberAttribute(entry.original, building, "HeliOrbitRadius", DEFAULT_RADIUS))
		local height = numberAttribute(entry.original, building, "HeliOrbitHeight", entry.authoredHeight)
		local orbitSpeed = numberAttribute(entry.original, building, "HeliOrbitSpeed", DEFAULT_ORBIT_SPEED)
		local yaw = math.rad(numberAttribute(entry.original, building, "HeliYaw", math.deg(DEFAULT_YAW)))
		local bladeSpeed = math.rad(numberAttribute(entry.original, building, "HeliBladeSpeed", math.deg(DEFAULT_BLADE_SPEED)))
		local frame = flightFrame(
			entry.base.Position,
			entry.phase + elapsed * orbitSpeed,
			radius,
			height,
			yaw,
			entry.pathPhase
		)
		local spin = elapsed * bladeSpeed
		for _, item in entry.parts do
			local rotation = CFrame.identity
			if item.part == entry.bladeY then
				rotation = CFrame.Angles(0, spin, 0)
			elseif item.part == entry.bladeZ then
				rotation = CFrame.Angles(0, 0, spin)
			end
			item.part.CFrame = frame * item.relative * rotation
		end
	end
end

function Controller.start()
	if started then
		return
	end
	if LocalPlayer and LocalPlayer:GetAttribute("MyCityLoaded") ~= true then
		if not readyConnection then
			readyConnection = LocalPlayer:GetAttributeChangedSignal("MyCityLoaded"):Connect(function()
				if LocalPlayer:GetAttribute("MyCityLoaded") == true then
					readyConnection:Disconnect()
					readyConnection = nil
					Controller.start()
				end
			end)
		end
		return
	end
	started = true
	local parent = Workspace:FindFirstChild("Misc") or Workspace
	animationFolder = parent:FindFirstChild("BuildingAnimations")
	if not animationFolder then
		animationFolder = Instance.new("Folder")
		animationFolder.Name = "BuildingAnimations"
		animationFolder.Parent = parent
	end
	for _, item in Workspace:GetDescendants() do
		add(item)
	end
	table.insert(connections, Workspace.DescendantAdded:Connect(function(item)
		local building = militaryBuilding(item)
		if building then
			add(building)
		end
	end))
	table.insert(connections, Workspace.DescendantRemoving:Connect(function(item)
		local building = militaryBuilding(item)
		local entry = building and entries[building]
		if
			entry
			and (item == building or item == entry.base or item == entry.original or item:IsDescendantOf(entry.original))
		then
			restore(entry)
		end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(update))
end

function Controller.stop()
	if readyConnection then
		readyConnection:Disconnect()
		readyConnection = nil
	end
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	local active = {}
	for _, entry in entries do
		table.insert(active, entry)
	end
	for _, entry in active do
		restore(entry)
	end
	if animationFolder and #animationFolder:GetChildren() == 0 then
		animationFolder:Destroy()
	end
	animationFolder = nil
	elapsed = 0
end

return Controller
