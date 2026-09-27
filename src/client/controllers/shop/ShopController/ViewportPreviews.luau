-- Shop adapter for the shared non-inventory building viewport renderer.
return function(Context)
	local State, Renderer = Context.State, Context.BuildingViewport
	State.viewportHosts = {}
	Context.viewportCameraDistance = Renderer.cameraDistance
	function Context.clearViewportPreviews()
		for _, host in State.viewportHosts do Renderer.detach(host) end
		State.viewportHosts = {}
	end
	function Context.createBuildingViewport(frame, buildingName)
		local icon = frame:FindFirstChild("BuildingIcon")
		local host = icon and icon:FindFirstChild("ImageLabel")
		if not (host and host:IsA("ImageLabel")) then return nil end
		table.insert(State.viewportHosts, host)
		return Renderer.attach(host, buildingName, { clip = State.ItemList })
	end
	function Context.startViewportAnimation() end
	function Context.stopViewportAnimation() end
end
