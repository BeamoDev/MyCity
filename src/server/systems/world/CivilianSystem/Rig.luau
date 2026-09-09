local Config = require(script.Parent.Config)
local Animations = require(script.Parent.Animations)
local Appearance = require(script.Parent.Appearance)
local Rig = {}
function Rig.describe(template)
	if not template or not template:IsA("Model") or not template.Archivable then
		return nil
	end
	local humanoid = template:FindFirstChildWhichIsA("Humanoid", true)
	local root = template:FindFirstChild("HumanoidRootPart", true)
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	return {
		radius = math.max(0.2, math.max(root.Size.X, root.Size.Z) / 2),
		-- R6 HipHeight is commonly zero; include torso/head/legs in its navigation clearance.
		height = math.max(1, root.Size.Y * 2.5, root.Size.Y + humanoid.HipHeight * 2),
	}
end
local function prepare(model, folder, ownerId, position, size)
	-- Disable embedded NPC logic before entering Workspace; this service owns AI.
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ProximityPrompt") then
			item:Destroy()
		end
	end
	Appearance.apply(model)
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	local root = model:FindFirstChild("HumanoidRootPart", true)
	model.Name = "Civilian"
	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", ownerId)
	model:SetAttribute("MyCityCivilian", true)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = item ~= root
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = true
	humanoid.Sit, humanoid.PlatformStand = false, false
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	local pivot = model:GetPivot()
	local box, bounds = model:GetBoundingBox()
	local bottom = box.Position.Y - bounds.Y / 2 - pivot.Position.Y
	model:PivotTo(CFrame.new(position + Vector3.new(0, -bottom + 0.02, 0)))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local record = {
		model = model,
		root = root,
		humanoid = humanoid,
		radius = size.radius,
		height = size.height,
		pauseUntil = os.clock(),
		active = true,
	}
	Animations.start(record)
	return record
end
function Rig.create(template, folder, ownerId, position, size)
	local model = template:Clone()
	local ok, record = pcall(prepare, model, folder, ownerId, position, size)
	if not ok then
		model:Destroy()
		error(record)
	end
	return record
end
function Rig.destroy(record)
	record.active = false
	Animations.destroy(record)
	record.model:Destroy()
end
return Rig
