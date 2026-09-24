-- Completes authored building templates in ServerStorage.Buildings once at startup.
-- Authors only provide a Model whose PrimaryPart is Base plus the building's visual parts.
-- This generates the Hitbox (sized to the whole building), copies Assets.Hitbox effects into it,
-- adds Assets.IncomeAlert, and welds every part to Base so completion rise tweens move the model.
local Templates = {}
local PREPARED = "MyCityTemplatePrepared"
local WELD = "MyCityWeld"
local warned = {}

local function warnOnce(key, message)
	if not warned[key] then
		warned[key] = true
		warn("[BuildingTemplates] " .. message)
	end
end

local function resolveBase(model)
	local base = model:FindFirstChild("Base")
	if not (base and base:IsA("BasePart")) then
		base = model.PrimaryPart
		if not base then
			return nil
		end
		-- Placement, validation and construction all look the footprint up by name.
		base.Name = "Base"
	end
	model.PrimaryPart = base
	return base
end

-- Bounding box of every part, expressed in Base's frame so rotated templates stay tight.
local function measure(base, parts)
	local minimum, maximum
	for _, part in parts do
		local half = part.Size / 2
		local relative = base.CFrame:ToObjectSpace(part.CFrame)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local point = relative * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					minimum = if minimum then minimum:Min(point) else point
					maximum = if maximum then maximum:Max(point) else point
				end
			end
		end
	end
	local size = maximum - minimum
	return base.CFrame * CFrame.new((minimum + maximum) / 2),
		Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
end

local function createHitbox(model, base, parts)
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.CFrame, hitbox.Size = measure(base, parts)
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	hitbox.CanCollide, hitbox.CanTouch, hitbox.CanQuery = false, false, false
	hitbox.Massless = true
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Parent = model
	return hitbox
end

local function weldedToBase(base, part)
	for _, joint in base:GetChildren() do
		if joint:IsA("WeldConstraint") and (joint.Part1 == part or joint.Part0 == part) then
			return true
		end
	end
	for _, joint in part:GetChildren() do
		if joint:IsA("WeldConstraint") and (joint.Part0 == base or joint.Part1 == base) then
			return true
		end
	end
	return false
end

function Templates.prepare(model, assets)
	if not model:IsA("Model") or model:GetAttribute(PREPARED) then
		return model:GetAttribute(PREPARED) == true
	end
	local base = resolveBase(model)
	if not base then
		warnOnce(model.Name, model.Name .. " has no Base/PrimaryPart and cannot be placed")
		return false
	end
	local parts = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "Hitbox" then
			table.insert(parts, item)
		elseif item:IsA("Attachment") and not item.Parent:IsA("BasePart") and not item.Parent:IsA("Attachment") then
			-- Attachments outside a part (e.g. road Exit markers under the Model) are re-homed on Base so
			-- they move and rotate with placed copies. Their stored CFrame may be a world position, or
			-- still relative to the part they were made in; keep whichever reading lands on this piece.
			local asWorld, asLocal = item.CFrame, base.CFrame * item.CFrame
			local function away(frame)
				local offset = frame.Position - base.CFrame.Position
				return Vector3.new(offset.X, 0, offset.Z).Magnitude
			end
			local world = if away(asLocal) < away(asWorld) then asLocal else asWorld
			item.Parent = base
			item.CFrame = base.CFrame:ToObjectSpace(world)
		end
	end
	local hitbox = model:FindFirstChild("Hitbox")
	if not (hitbox and hitbox:IsA("BasePart")) then
		hitbox = createHitbox(model, base, parts)
	end
	table.insert(parts, hitbox)

	local effects = assets and assets:FindFirstChild("Hitbox")
	if effects then
		for _, effect in effects:GetChildren() do
			if not hitbox:FindFirstChild(effect.Name) then
				effect:Clone().Parent = hitbox
			end
		end
	else
		warnOnce("Assets.Hitbox", "Missing ReplicatedStorage.Assets.Hitbox; buildings have no placement/completion VFX")
	end

	local alertTemplate = assets and assets:FindFirstChild("IncomeAlert")
	if not model:FindFirstChild("IncomeAlert") then
		if alertTemplate and alertTemplate:IsA("BillboardGui") then
			local alert = alertTemplate:Clone()
			alert.Enabled = false
			alert.Adornee = hitbox
			-- Float above the roof instead of the Hitbox centre (inside tall buildings).
			if alert.ExtentsOffsetWorldSpace == Vector3.zero then
				alert.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
			end
			alert.Parent = model
		else
			warnOnce("Assets.IncomeAlert", "ReplicatedStorage.Assets.IncomeAlert must be a BillboardGui")
		end
	end

	-- Base stays anchored; everything else rides on it so PrimaryPart tweens move the building.
	base.Anchored = true
	for _, part in parts do
		if part ~= base then
			if not weldedToBase(base, part) then
				local weld = Instance.new("WeldConstraint")
				weld.Name = WELD
				weld.Part0, weld.Part1 = base, part
				weld.Parent = base
			end
			part.Anchored = false
		end
	end
	model:SetAttribute(PREPARED, true)
	return true
end

local function footprint(part)
	return math.min(part.Size.X, part.Size.Z), math.max(part.Size.X, part.Size.Z)
end

-- Reports config/model mismatches once at startup so a new building's mistakes are obvious.
function Templates.audit(models, catalogue, assets)
	local problems = {}
	local constructions = assets and assets:FindFirstChild("Constructions")
	for name, definition in catalogue do
		local model = models:FindFirstChild(name)
		if not model then
			table.insert(problems, name .. " is in BuildingConfig but ServerStorage.Buildings has no model")
			continue
		end
		local base = model:FindFirstChild("Base")
		local site = constructions and definition.Size and constructions:FindFirstChild(definition.Size)
		local siteBase = site and (site:FindFirstChild("Base") or site.PrimaryPart)
		if not site then
			table.insert(problems, name .. ' uses Size "' .. tostring(definition.Size) .. '" with no Assets.Constructions model')
		elseif base and siteBase and siteBase:IsA("BasePart") then
			local short, long = footprint(base)
			local siteShort, siteLong = footprint(siteBase)
			if math.abs(short - siteShort) > 1 or math.abs(long - siteLong) > 1 then
				table.insert(
					problems,
					string.format(
						"%s Base is %.0fx%.0f studs but its %s construction site is %.0fx%.0f; check Size",
						name,
						short,
						long,
						definition.Size,
						siteShort,
						siteLong
					)
				)
			end
		end
	end
	table.sort(problems)
	for _, problem in problems do
		warnOnce(problem, problem)
	end
	return problems
end

return Templates
