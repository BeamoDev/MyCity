-- Highway cars visiting cities. Each Map ...PlotCutOffs.Plot<N> model marks its slip roads with
-- Attachments named EnterPlot... (e.g. EnterPlot1-3) and ExitPlot... (ExitPlot1-3). Numbering does
-- not matter: each set is ordered by distance from the plot, so cars drive the entry points from
-- the highway to the plot edge and the exit points from the plot edge back to the highway. A visit
-- happens only when a player's road has an open end within Config.ConnectDistance of both plot ends.
-- Every decision is logged with its reason ("[RoadTraffic] ..." in the server Output).
local Workspace = game:GetService("Workspace")
local UP = Vector3.new(0, 1, 0)
local LOG_EVERY = 20 -- seconds between repeated reasons for the same plot

return function(Context)
	local Graph, Config, cities = Context.Graph, Context.Config, Context.cities
	local cutoffs

	local function log(message)
		print("[RoadTraffic] " .. message)
	end

	-- Middle of the plot's land, used to tell the highway end of a slip road from the plot end.
	local function plotCentre(plot)
		local land = plot:FindFirstChild("Land")
		local sum, count = Vector3.zero, 0
		for _, part in (if land then land:GetDescendants() else {}) do
			if part:IsA("BasePart") then
				sum += part.CFrame.Position
				count += 1
			end
		end
		if count > 0 then
			return sum / count
		end
		local ok, pivot = pcall(plot.GetPivot, plot)
		return if ok then pivot.Position else Vector3.zero
	end

	-- Every Attachment whose name starts with `prefix` (EnterPlot, EnterPlot1.. or ExitPlot..),
	-- as world positions ordered from the highway (farthest from the plot) to the plot edge.
	local function slipRoad(cutoff, prefix, centre)
		local points = {}
		for _, item in cutoff:GetDescendants() do
			if item:IsA("Attachment") and item.Name:sub(1, #prefix) == prefix then
				table.insert(points, Graph.worldPosition(item))
			end
		end
		local function away(point)
			return Vector3.new(point.X - centre.X, 0, point.Z - centre.Z).Magnitude
		end
		table.sort(points, function(a, b)
			return away(a) > away(b)
		end)
		return points
	end

	local function findCutoffs()
		if cutoffs == nil then
			local map = Workspace:FindFirstChild("Map")
			cutoffs = (map and map:FindFirstChild("PlotCutOffs", true))
				or Workspace:FindFirstChild("PlotCutOffs", true)
				or false
			if not cutoffs then
				log("No PlotCutOffs folder found in Workspace; highway cars cannot visit plots")
			else
				log("Using " .. cutoffs:GetFullName() .. " (" .. #cutoffs:GetChildren() .. " plot cutoffs)")
				for _, cutoff in cutoffs:GetChildren() do
					local counts = {}
					for _, prefix in { "EnterPlot", "ExitPlot" } do
						local count = 0
						for _, item in cutoff:GetDescendants() do
							if item:IsA("Attachment") and item.Name:sub(1, #prefix) == prefix then
								count += 1
							end
						end
						table.insert(counts, count .. " " .. prefix)
					end
					log(cutoff.Name .. ": " .. table.concat(counts, ", ") .. " attachments")
				end
			end
		end
		return cutoffs or nil
	end

	-- Horizontal projection of a point onto the line first -> last.
	local function project(point, first, last)
		local a, b = first.Position, last.Position
		local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length2 = along:Dot(along)
		if length2 < 1e-6 then
			return nil
		end
		local t = Vector3.new(point.X - a.X, 0, point.Z - a.Z):Dot(along) / length2
		local onLine = a:Lerp(b, t)
		return t, Vector3.new(point.X - onLine.X, 0, point.Z - onLine.Z).Magnitude, onLine
	end

	-- The trip (of all highway routes) whose line passes closest to a point, with its projection.
	local function nearestTrip(point, trips)
		local best
		for _, trip in trips do
			local t, lateral, onLine = project(point, trip.first, trip.last)
			if t and t > 0.01 and t < 0.99 and (not best or lateral < best.lateral) then
				best = { trip = trip, t = t, lateral = lateral, onLine = onLine }
			end
		end
		return best
	end

	local function ground(position, model)
		return Vector3.new(position.X, Context.groundAt(position, model), position.Z)
	end

	-- Rotation that turns a heading-aligned frame into the highway's authored car orientation,
	-- so a visiting car keeps facing the same way it did on the highway.
	local function correctionFor(first, last)
		local heading = Graph.flat(last.Position - first.Position)
		local aligned = CFrame.fromMatrix(Vector3.zero, heading:Cross(UP), UP, -heading)
		return aligned:Inverse() * first.Rotation
	end

	-- Decides whether `cutoff`'s city can be visited. With `current` (a car's trip) the visit must
	-- turn off from that car's carriageway. Returns (option, nil) or (nil, reason).
	local function evaluate(cutoff, trips, current)
		local plots = Workspace:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild(cutoff.Name)
		if not plot then
			return nil, "no Workspace.Plots." .. cutoff.Name .. " matches this cutoff's name"
		end
		local city = cities[plot]
		if not city then
			return nil, "road traffic is not tracking this plot yet"
		end
		local centre = plotCentre(plot)
		-- Entering runs highway -> plot; leaving runs plot -> highway.
		local enter = slipRoad(cutoff, "EnterPlot", centre)
		local exit = slipRoad(cutoff, "ExitPlot", centre)
		if #enter == 0 or #exit == 0 then
			return nil,
				"PlotCutOffs."
					.. cutoff.Name
					.. " needs Attachments named EnterPlot... and ExitPlot... (found "
					.. #enter
					.. " and "
					.. #exit
					.. ")"
		end
		local reversed = {}
		for index = #exit, 1, -1 do
			table.insert(reversed, exit[index])
		end
		exit = reversed
		local points = {
			EnterHighway = enter[1],
			EnterEdge = enter[#enter],
			ExitEdge = exit[1],
			ExitHighway = exit[#exit],
		}
		if #city.pieces == 0 then
			return nil, "no roads built in this plot"
		end
		local ends = {}
		local labels = { EnterEdge = "the plot end of EnterPlot", ExitEdge = "the plot end of ExitPlot" }
		for _, key in { "EnterEdge", "ExitEdge" } do
			local name = labels[key]
			local roadEnd, distance = Graph.nearestOpenExit(city.pieces, points[key], Config.ConnectHeight)
			if not roadEnd then
				local total, open = 0, 0
				for _, piece in city.pieces do
					for _, exit in piece.exits do
						total += 1
						open += if #exit.links == 0 then 1 else 0
					end
				end
				local nearest = Graph.nearestOpenExit(city.pieces, points[key], math.huge)
				return nil,
					string.format(
						"no open road end within %d studs of the height of %s (Y %.1f). The plot has %d road pieces, %d road ends, %d open%s",
						Config.ConnectHeight,
						name,
						points[key].Y,
						#city.pieces,
						total,
						open,
						if nearest
							then string.format(
								"; nearest open end is at (%.0f, %.0f, %.0f)",
								nearest.position.X,
								nearest.position.Y,
								nearest.position.Z
							)
							else ""
					)
			end
			if distance > Config.ConnectDistance then
				return nil,
					string.format(
						"nearest open road end is %.1f studs from %s at (%.0f, %.0f, %.0f); needs %d or less",
						distance,
						name,
						points[key].X,
						points[key].Y,
						points[key].Z,
						Config.ConnectDistance
					)
			end
			ends[key] = roadEnd
		end
		local start, finish = Graph.entering(ends.EnterEdge), Graph.leaving(ends.ExitEdge)
		if not Graph.route(start, finish) then
			return nil,
				"the road at the plot end of EnterPlot is not joined to the road at the plot end of ExitPlot"
		end
		if not trips then
			return nil, "roads connected; waiting for the first highway car to check the highway side"
		end
		for key, name in { EnterHighway = "the highway end of EnterPlot", ExitHighway = "the highway end of ExitPlot" } do
			local near = nearestTrip(points[key], trips)
			if not near or near.lateral > Config.HighwayReach then
				return nil,
					string.format(
						"%s is %s studs from the highway lanes (max %d)",
						name,
						if near then string.format("%.1f", near.lateral) else "not alongside any of",
						Config.HighwayReach
					)
			end
		end
		local on, back = nearestTrip(points.EnterHighway, trips), nearestTrip(points.ExitHighway, trips)
		if current and on.trip.route ~= current.route then
			return nil, "other carriageway"
		end
		return {
			cutoff = cutoff,
			city = city,
			on = on,
			back = back,
			start = start,
			finish = finish,
			enter = enter,
			exit = exit,
		}
	end

	-- Why a city can (not) be visited, in words a builder can act on (nil if the plot has no cutoff).
	function Context.status(plot, city)
		local folder = findCutoffs()
		local cutoff = folder and folder:FindFirstChild(plot.Name)
		if not cutoff then
			return nil
		end
		local option, reason = evaluate(cutoff, Context.trips)
		return if option then "connected: highway cars can drive in" else reason
	end

	local reported = setmetatable({}, { __mode = "k" })
	function Context.report(plot, city)
		local ok, message = pcall(Context.status, plot, city)
		message = if ok then message else "status check failed: " .. tostring(message)
		-- Empty plots stay quiet until they have had roads.
		if message == "no roads built in this plot" and reported[plot] == nil then
			return
		end
		if message and reported[plot] ~= message then
			reported[plot] = message
			log(plot.Name .. " highway link: " .. message)
			if message:find(" 0 open") then
				-- Show every road end so a layout problem can be seen at a glance.
				for _, piece in city.pieces do
					local ends = {}
					for _, exit in piece.exits do
						table.insert(
							ends,
							string.format(
								"%s@(%.1f, %.1f, %.1f) facing (%.0f, %.0f) joined %d",
								exit.name,
								exit.position.X,
								exit.position.Y,
								exit.position.Z,
								exit.normal.X,
								exit.normal.Z,
								#exit.links
							)
						)
					end
					log("  " .. piece.model.Name .. ": " .. table.concat(ends, "; "))
				end
			end
		end
	end

	local lastSkip = {}
	local function explainSkip(cutoff, reason)
		-- Only plots with roads are interesting; "other carriageway" is normal for half the cars.
		if reason == "no roads built in this plot" or reason == "other carriageway" then
			return
		end
		local now = os.clock()
		if lastSkip[cutoff.Name] and now - lastSkip[cutoff.Name] < LOG_EVERY then
			return
		end
		lastSkip[cutoff.Name] = now
		log(cutoff.Name .. " not visited: " .. reason)
	end

	-- trips: every highway route's trip ({ route, first, last }) at this car's lane offset; current is
	-- the one the car drives. Returns a list of CFrames for a visit, or nil to stay on the highway.
	function Context.divert(current, trips, template)
		local first, last = current.first, current.last
		-- Remember the highway's car orientation so city-only cars face the same way.
		Context.correction = correctionFor(first, last)
		if not Context.trips then
			-- First highway car: highway lanes are now known, so explain every city's link state.
			Context.trips = trips
			log(#trips .. " highway lanes found; checking plot links")
			for plot, city in cities do
				Context.report(plot, city)
			end
		end
		local folder = findCutoffs()
		if not folder or math.random() > Config.VisitChance then
			return nil
		end
		local options = {}
		for _, cutoff in folder:GetChildren() do
			local option, reason = evaluate(cutoff, trips, current)
			if option then
				table.insert(options, option)
			else
				explainSkip(cutoff, reason)
			end
		end
		if #options == 0 then
			return nil
		end
		local visit = options[math.random(1, #options)]
		local tour = Graph.visit(visit.start, visit.finish, visit.city.pieces, math.random)
		if not tour then
			log(visit.cutoff.Name .. " not visited: could not plan a drive through the city roads")
			return nil
		end
		local raw = {}
		for _, point in visit.enter do
			table.insert(raw, { position = ground(point, visit.cutoff) })
		end
		table.move(tour, 1, #tour, #raw + 1, raw)
		for _, point in visit.exit do
			table.insert(raw, { position = ground(point, visit.cutoff) })
		end
		local slip = Graph.frames(raw, Context.liftOf(template), nil, correctionFor(first, last))
		local backTrip = visit.back.trip
		local frames = { first, CFrame.new(visit.on.onLine) * first.Rotation }
		table.move(slip, 1, #slip, #frames + 1, frames)
		table.insert(frames, CFrame.new(visit.back.onLine) * backTrip.first.Rotation)
		table.insert(frames, backTrip.last)
		local carName = if template then template.Name else "car"
		log(string.format("A %s is driving into %s (%d waypoints)", carName, visit.cutoff.Name, #frames))
		return frames
	end
end
