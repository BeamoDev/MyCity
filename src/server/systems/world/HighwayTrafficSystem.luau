local Traffic = require(script.Parent.AmbientTraffic)
return Traffic.new({
	System = "RoadSystem",
	Folder = "ActiveCars",
	Templates = "CarTemplates",
	Limit = 25,
	Speed = 5,
	MinInterval = 1,
	MaxInterval = 4,
	LaneOffset = 1.8,
	Routes = { { "Point3", "Point4", -90 }, { "Point6", "Point5", 90 } },
})
