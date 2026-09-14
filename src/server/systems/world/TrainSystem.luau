local Traffic = require(script.Parent.AmbientTraffic)
return Traffic.new({
	System = "TrainSystem",
	Folder = "ActiveTrains",
	Templates = "Trains",
	Template = "Train",
	Limit = 3,
	Duration = 40,
	MinInterval = 20,
	MaxInterval = 40,
	LaneOffset = 0,
	ExclusiveRoute = true,
	Routes = { { "Point3", "Point4", 90 }, { "Point1", "Point2", 90 } },
})
