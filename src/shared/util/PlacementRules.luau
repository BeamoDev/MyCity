-- One placement rule set for the client preview and server validation, so green always means accepted.
-- Land is checked against Owned tile rectangles, and overlap against other buildings' Base footprints.
-- Decorations, Hitboxes, expansion signs and locked-tile scenery can never block a placement.
local Rules = {}
-- Footprints may touch or overlap by float noise; edges within this distance count as touching.
Rules.Tolerance = 0.05
Rules.Messages = {
	OutsideLand = "Cannot place here: part of the building is outside your land.",
	Overlap = "Cannot place here: it overlaps another building.",
	Height = "Cannot place here: the building must sit on your land.",
	TooFar = "Too far from your plot to place a building. Return to your city.",
}

local function flat(vector)
	local length = math.sqrt(vector.X * vector.X + vector.Z * vector.Z)
	return if length > 0 then Vector3.new(vector.X / length, 0, vector.Z / length) else Vector3.new(1, 0, 0)
end

local function rectangle(cframe, size)
	return {
		center = Vector3.new(cframe.Position.X, 0, cframe.Position.Z),
		axes = { flat(cframe.RightVector), flat(cframe.LookVector) },
		half = { size.X / 2, size.Z / 2 },
	}
end

local function radius(shape, axis)
	return shape.half[1] * math.abs(shape.axes[1]:Dot(axis)) + shape.half[2] * math.abs(shape.axes[2]:Dot(axis))
end

-- Separating-axis test for two upright rectangles; touching edges do not overlap.
function Rules.overlaps(aCFrame, aSize, bCFrame, bSize)
	local a, b = rectangle(aCFrame, aSize), rectangle(bCFrame, bSize)
	local offset = b.center - a.center
	for _, axis in { a.axes[1], a.axes[2], b.axes[1], b.axes[2] } do
		if math.abs(offset:Dot(axis)) >= radius(a, axis) + radius(b, axis) - Rules.Tolerance then
			return false
		end
	end
	return true
end

local function footprintOf(model)
	local base = model:FindFirstChild("Base")
	if not (base and base:IsA("BasePart")) then
		base = model.PrimaryPart
	end
	return base
end

function Rules.ownedTiles(plot)
	local land = plot and plot:FindFirstChild("Land")
	local owned = land and land:FindFirstChild("Owned")
	local tiles = {}
	for _, tile in (if owned then owned:GetChildren() else {}) do
		if tile:IsA("BasePart") then
			table.insert(tiles, tile)
		end
	end
	return tiles
end

local function tileAt(tiles, point)
	for _, tile in tiles do
		local local_ = tile.CFrame:PointToObjectSpace(point)
		if math.abs(local_.X) <= tile.Size.X / 2 + 0.01 and math.abs(local_.Z) <= tile.Size.Z / 2 + 0.01 then
			return tile
		end
	end
	return nil
end
Rules.tileAt = tileAt

-- Samples the footprint (edges pulled in by Tolerance) at most one stud apart; land gaps are whole tiles.
function Rules.onOwnedLand(tiles, cframe, size)
	local inset = Rules.Tolerance
	local width, depth = math.max(size.X - inset * 2, 0), math.max(size.Z - inset * 2, 0)
	local stepsX, stepsZ = math.max(1, math.ceil(width)), math.max(1, math.ceil(depth))
	for x = 0, stepsX do
		for z = 0, stepsZ do
			local point = cframe:PointToWorldSpace(
				Vector3.new(-width / 2 + width * x / stepsX, 0, -depth / 2 + depth * z / stepsZ)
			)
			if not tileAt(tiles, point) then
				return false
			end
		end
	end
	return true
end

-- Returns the first building/construction model whose Base footprint overlaps, if any.
function Rules.blockingBuilding(plot, cframe, size, ignore)
	local buildings = plot and plot:FindFirstChild("Buildings")
	for _, folderName in { "Placed", "Construction" } do
		local folder = buildings and buildings:FindFirstChild(folderName)
		for _, model in (if folder then folder:GetChildren() else {}) do
			if model ~= ignore and model:IsA("Model") then
				local base = footprintOf(model)
				if base and Rules.overlaps(cframe, size, base.CFrame, base.Size) then
					return model
				end
			end
		end
	end
	return nil
end

-- cframe/size describe the candidate Base. Returns true, or false plus a reason key from Messages.
function Rules.check(plot, cframe, size, ignore)
	if not Rules.onOwnedLand(Rules.ownedTiles(plot), cframe, size) then
		return false, "OutsideLand"
	end
	if Rules.blockingBuilding(plot, cframe, size, ignore) then
		return false, "Overlap"
	end
	return true
end

return Rules
