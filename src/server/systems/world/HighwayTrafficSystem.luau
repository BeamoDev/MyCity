local Traffic = require(script.Parent.AmbientTraffic)
return Traffic.new({
	System = "RoadSystem",
	Folder = "ActiveCars",
	Templates = "CarTemplates",
	Limit = 25,
	Speed = 5 / 3, -- studs per second (3x slower than the original 5); visiting cars use this too
	MinInterval = 1,
	MaxInterval = 4,
	LaneOffset = 1.8,
	Routes = { { "Point3", "Point4", -90 }, { "Point6", "Point5", 90 } },
	-- Some cars turn off into cities whose roads connect to the plot slip roads.
	Divert = function(current, trips, template)
		return require(script.Parent.RoadTraffic).divert(current, trips, template)
	end,
})
