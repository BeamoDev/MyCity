-- Road network from placed road pieces. Each piece marks its open edges with Attachments whose names
-- contain "Exit" (Exit1, InsideLaneExit, ...), and optionally a "DeadEnd" turnaround point.
-- Exits of different pieces that meet (within MatchDistance) are linked; cars enter a piece at one
-- exit and leave by an exit on a different edge, turning around at dead ends and open road ends.
local Graph = {}
Graph.MatchDistance = 2.5
Graph.SameEdgeDot = 0.5 -- exits whose directions from the centre are closer than 60 degrees share an edge
Graph.LaneShare = 0.15 -- default lane offset as a share of the road's narrow Base side

local UP = Vector3.new(0, 1, 0)

local function flat(vector)
	local v = Vector3.new(vector.X, 0, vector.Z)
	return if v.Magnitude > 1e-4 then v.Unit else Vector3.new(0, 0, -1)
end

local function edgeNormal(base, offset)
	if not base then
		return flat(offset)
	end
	local localOffset = base.CFrame:VectorToObjectSpace(offset)
	local axis = if math.abs(localOffset.X) >= math.abs(localOffset.Z)
		then Vector3.new(if localOffset.X >= 0 then 1 else -1, 0, 0)
		else Vector3.new(0, 0, if localOffset.Z >= 0 then 1 else -1)
	return flat(base.CFrame:VectorToWorldSpace(axis))
end

local function worldPosition(attachment)
	local parent = attachment.Parent
	if parent and parent:IsA("BasePart") then
		return (parent.CFrame * attachment.CFrame).Position
	end
	-- Not inside a part (e.g. PlotCutOffs markers under a Model): the stored CFrame is either a world
	-- position or still relative to a part it was made in. Keep whichever lands nearer the model.
	local asWorld = attachment.CFrame.Position
	local model = attachment:FindFirstAncestorWhichIsA("Model")
	local reference = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if not reference then
		return asWorld
	end
	local asLocal = (reference.CFrame * attachment.CFrame).Position
	local ok, centre = pcall(function()
		return (model:GetBoundingBox()).Position
	end)
	centre = if ok then centre else reference.CFrame.Position
	local function away(position)
		return Vector3.new(position.X - centre.X, 0, position.Z - centre.Z).Magnitude
	end
	return if away(asLocal) < away(asWorld) then asLocal else asWorld
end

local function markers(model)
	local exits, deadEnd = {}, nil
	for _, item in model:GetDescendants() do
		if item:IsA("Attachment") then
			if item.Name:find("Exit") then
				table.insert(exits, item)
			elseif item.Name:find("DeadEnd") then
				deadEnd = item
			end
		end
	end
	return exits, deadEnd
end

function Graph.isRoad(model)
	if not model:IsA("Model") then
		return false
	end
	return #(markers(model)) > 0
end

-- groundAt(position, model) -> surface Y; defaults to the attachment height.
function Graph.readPiece(model, groundAt, defaultOffset)
	local attachments, deadEndMarker = markers(model)
	if #attachments == 0 then
		return nil
	end
	local base = model:FindFirstChild("Base") or model.PrimaryPart
	local centre = if base then base.CFrame.Position else model:GetPivot().Position
	local function ground(position)
		local y = if groundAt then groundAt(position, model) else position.Y
		return Vector3.new(position.X, y, position.Z)
	end
	local piece = { model = model, exits = {}, centre = ground(centre) }
	for _, attachment in attachments do
		local position = ground(worldPosition(attachment))
		table.insert(piece.exits, {
			piece = piece,
			name = attachment.Name,
			position = position,
			-- Outward normal of the edge this exit sits on (snapped to Base's axes, so lane
			-- exits beside each other share an edge even though they are off-centre).
			normal = edgeNormal(base, position - piece.centre),
			links = {},
		})
	end
	if deadEndMarker then
		piece.deadEnd = ground(worldPosition(deadEndMarker))
	end
	-- Pieces with separate per-lane exits on one edge already place cars in lanes.
	local laneExits = false
	for i, a in piece.exits do
		for j = i + 1, #piece.exits do
			if a.normal:Dot(piece.exits[j].normal) > 0.95 then
				laneExits = true
			end
		end
	end
	local authored = model:GetAttribute("LaneOffset")
	if type(authored) == "number" then
		piece.laneOffset = authored
	elseif laneExits then
		piece.laneOffset = 0
	elseif defaultOffset then
		piece.laneOffset = defaultOffset
	else
		local size = if base then base.Size else Vector3.new(8, 1, 8)
		piece.laneOffset = math.min(size.X, size.Z) * Graph.LaneShare
	end
	return piece
end

local function cell(position)
	return math.floor(position.X / Graph.MatchDistance), math.floor(position.Z / Graph.MatchDistance)
end

function Graph.build(models, groundAt, defaultOffset)
	local pieces, buckets = {}, {}
	for _, model in models do
		local piece = Graph.readPiece(model, groundAt, defaultOffset)
		if piece then
			table.insert(pieces, piece)
			for _, exit in piece.exits do
				local x, z = cell(exit.position)
				local key = x .. ":" .. z
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], exit)
			end
		end
	end
	for _, piece in pieces do
		for _, exit in piece.exits do
			local x, z = cell(exit.position)
			for dx = -1, 1 do
				for dz = -1, 1 do
					for _, other in buckets[(x + dx) .. ":" .. (z + dz)] or {} do
						local offset = other.position - exit.position
						-- A real join: close together, similar height and the two edges facing each other
						-- (pieces lying side by side have parallel edges and must not join).
						if
							other.piece ~= piece
							and Vector3.new(offset.X, 0, offset.Z).Magnitude <= Graph.MatchDistance
							and math.abs(offset.Y) <= 2
							and exit.normal:Dot(other.normal) < -0.7
						then
							table.insert(exit.links, other)
						end
					end
				end
			end
		end
	end
	return pieces
end

-- Of several exits on one edge (per-lane markers), the one on the right-hand side for `heading`.
function Graph.rightLane(exits, heading)
	local right, best, bestScore = heading:Cross(UP), nil, -math.huge
	for _, exit in exits do
		local score = exit.position:Dot(right)
		if score > bestScore then
			best, bestScore = exit, score
		end
	end
	return best
end

-- One exit per other edge a car entering at `entry` may leave by, using that edge's right-hand lane.
function Graph.onward(entry)
	local edges = {}
	for _, exit in entry.piece.exits do
		if exit ~= entry and entry.normal:Dot(exit.normal) < Graph.SameEdgeDot then
			local edge
			for _, group in edges do
				if group[1].normal:Dot(exit.normal) > 0.95 then
					edge = group
					break
				end
			end
			if edge then
				table.insert(edge, exit)
			else
				table.insert(edges, { exit })
			end
		end
	end
	local choices = {}
	for _, group in edges do
		table.insert(choices, Graph.rightLane(group, group[1].normal))
	end
	return choices
end

-- Entering the next piece: among the exits linked to `leave`, the right-hand lane for inbound travel.
function Graph.enter(leave)
	if #leave.links == 0 then
		return nil
	end
	return Graph.rightLane(leave.links, -leave.links[1].normal)
end

local function bezier(a, control, b, samples, out)
	for i = 1, samples do
		local t = i / samples
		local u = 1 - t
		table.insert(out, { position = a * (u * u) + control * (2 * u * t) + b * (t * t) })
	end
end

-- A half-circle from the right-hand lane to the opposite lane, so a car turns instead of spinning.
local function uTurn(at, heading, offset, out)
	local right = heading:Cross(UP)
	for step = 1, 3 do
		local angle = math.pi * step / 4
		table.insert(out, {
			position = at + right * (math.cos(angle) * offset) + heading * (math.sin(angle) * offset),
			turning = true,
		})
	end
end

-- Appends the drive across one piece from `entry` to `leave` (or to the turnaround if leave is nil).
function Graph.traverse(entry, leave, out)
	local piece = entry.piece
	local start = entry.position
	if #out == 0 then
		table.insert(out, { position = start, offset = piece.laneOffset })
	end
	if not leave then
		local turnAt = piece.deadEnd or piece.centre
		table.insert(out, { position = turnAt, offset = piece.laneOffset })
		uTurn(turnAt, flat(turnAt - start), piece.laneOffset, out)
		table.insert(out, { position = start, offset = piece.laneOffset })
		return
	end
	local finish = leave.position
	if entry.normal:Dot(leave.normal) < -0.95 then
		table.insert(out, { position = finish, offset = piece.laneOffset })
	else
		-- Corner where the entry lane line meets the exit lane line.
		local corner = start + entry.normal * (finish - start):Dot(entry.normal)
		local control = Vector3.new(corner.X, (start.Y + finish.Y) / 2, corner.Z)
		local before = #out
		bezier(start, control, finish, 4, out)
		for i = before + 1, #out do
			out[i].offset = piece.laneOffset
		end
	end
end

-- Drives across entry's piece to `leave` (nil = dead-end turnaround), then into the next piece.
-- Returns the next entry exit; at an open road end the car U-turns and re-enters the same piece.
function Graph.step(entry, leave, out)
	Graph.traverse(entry, leave, out)
	leave = leave or entry
	local nextEntry = Graph.enter(leave)
	if nextEntry then
		return nextEntry
	end
	local last = out[#out].position
	local previous = out[#out - 1] and out[#out - 1].position or leave.piece.centre
	uTurn(last, flat(last - previous), leave.piece.laneOffset, out)
	return leave
end

-- Exits a car entering at `entry` may leave by; false means turn around at a dead end.
function Graph.choices(entry)
	local choices = Graph.onward(entry)
	return if #choices > 0 then choices else { false }
end

-- The entry exit a car uses when it drives into `exit`'s edge (right-hand lane for inbound travel).
function Graph.entering(exit)
	local sameEdge = {}
	for _, other in exit.piece.exits do
		if other.normal:Dot(exit.normal) > 0.95 then
			table.insert(sameEdge, other)
		end
	end
	return Graph.rightLane(sameEdge, -exit.normal)
end

-- The exit a car uses when it drives out of `exit`'s edge (right-hand lane for outbound travel).
function Graph.leaving(exit)
	local sameEdge = {}
	for _, other in exit.piece.exits do
		if other.normal:Dot(exit.normal) > 0.95 then
			table.insert(sameEdge, other)
		end
	end
	return Graph.rightLane(sameEdge, exit.normal)
end

-- Breadth-first search over entry exits. Returns the list of { entry, leave } moves (leave nil =
-- dead-end turnaround) ending with the first move whose outgoing exit satisfies isGoal, or nil.
local function search(start, isGoal, limit)
	local queue, head, seen = { { entry = start } }, 1, { [start] = true }
	while queue[head] and head <= limit do
		local node = queue[head]
		head += 1
		for _, choice in Graph.choices(node.entry) do
			local leave = choice or nil
			local out = leave or node.entry
			local move = { entry = node.entry, leave = leave }
			if isGoal(out) then
				local moves, cursor = { move }, node
				while cursor.move do
					table.insert(moves, 1, cursor.move)
					cursor = cursor.parent
				end
				return moves
			end
			-- Same rule as Graph.step: an open road end turns the car around into the same piece.
			local nextEntry = Graph.enter(out) or out
			if not seen[nextEntry] then
				seen[nextEntry] = true
				table.insert(queue, { entry = nextEntry, parent = node, move = move })
			end
		end
	end
	return nil
end

function Graph.route(start, target, limit)
	return search(start, function(out)
		return out == target
	end, limit or 500)
end

-- Raw waypoints from `start` (entry exit) to leaving by `target`, detouring through a random piece
-- so visiting cars tour the city. Nil when target cannot be reached.
function Graph.visit(start, target, pieces, random)
	local moves
	local via = pieces[random(1, #pieces)]
	if via ~= start.piece then
		local first = search(start, function(out)
			local nextEntry = Graph.enter(out)
			return nextEntry ~= nil and nextEntry.piece == via
		end, 500)
		local last = first and first[#first]
		local middle = last and Graph.enter(last.leave or last.entry)
		local second = middle and Graph.route(middle, target)
		if second then
			moves = table.move(second, 1, #second, #first + 1, first)
		end
	end
	moves = moves or Graph.route(start, target)
	if not moves then
		return nil
	end
	local out = {}
	for index, move in moves do
		if index < #moves then
			Graph.step(move.entry, move.leave, out)
		else
			Graph.traverse(move.entry, move.leave, out)
		end
	end
	return out
end

-- Nearest unlinked (open) exit to a point within `height` vertically: where a player's road meets a
-- fixed marker. Returns the exit and its horizontal distance (nil when there is no open exit).
function Graph.nearestOpenExit(pieces, point, height)
	local best, bestDistance = nil, math.huge
	for _, piece in pieces do
		for _, exit in piece.exits do
			local offset = exit.position - point
			local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if #exit.links == 0 and math.abs(offset.Y) <= (height or 6) and flatDistance < bestDistance then
				best, bestDistance = exit, flatDistance
			end
		end
	end
	return best, if best then bestDistance else nil
end

function Graph.openExitNear(pieces, point, distance, height)
	local exit, found = Graph.nearestOpenExit(pieces, point, height)
	return if exit and found <= distance then exit else nil
end

Graph.worldPosition = worldPosition
Graph.flat = flat

-- Plans a trip of up to maxPieces pieces from a random piece. Returns raw waypoints (with lane offsets).
function Graph.plan(pieces, random, maxPieces)
	local candidates = {}
	for _, piece in pieces do
		if #piece.exits > 0 then
			table.insert(candidates, piece)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local piece = candidates[random(1, #candidates)]
	local entry = Graph.entering(piece.exits[random(1, #piece.exits)])
	local out = {}
	for _ = 1, maxPieces do
		local choices = Graph.choices(entry)
		local leave = choices[random(1, #choices)]
		entry = Graph.step(entry, leave or nil, out)
	end
	return out
end

-- Applies right-hand lane offsets and headings. Returns CFrames for the vehicle's PrimaryPart
-- (lift raises it from the road surface; yaw corrects templates not modelled facing -Z).
function Graph.frames(points, lift, yaw, correction)
	local frames = {}
	for i, point in points do
		local ahead = points[math.min(i + 1, #points)].position - point.position
		local behind = point.position - points[math.max(i - 1, 1)].position
		local heading = flat(ahead + behind)
		local offset = if point.turning then 0 else (point.offset or 0)
		local position = point.position + heading:Cross(UP) * offset + Vector3.new(0, lift or 0, 0)
		-- Right, up and back (= -heading) axes: LookVector is the heading.
		frames[i] = CFrame.fromMatrix(position, heading:Cross(UP), UP, -heading)
			* (correction or CFrame.Angles(0, math.rad(yaw or 0), 0))
	end
	-- Drop consecutive duplicates so zero-length segments cannot divide by zero on clients.
	local cleaned = {}
	for _, frame in frames do
		local last = cleaned[#cleaned]
		if not last or (last.Position - frame.Position).Magnitude > 0.05 then
			table.insert(cleaned, frame)
		end
	end
	return cleaned
end

function Graph.length(frames)
	local total = 0
	for i = 2, #frames do
		total += (frames[i].Position - frames[i - 1].Position).Magnitude
	end
	return total
end

return Graph
