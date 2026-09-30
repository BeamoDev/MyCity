return function(plot)
	local ui = plot:FindFirstChild("UI")
	if not ui then return end

	local citySign = ui:FindFirstChild("CitySign")
	local body = citySign and citySign:FindFirstChild("Body")
	local surface = body and body:FindFirstChild("SurfaceGui")
	local frame = surface and surface:FindFirstChild("Frame")
	local cityName = frame and frame:FindFirstChild("CityName")
	if cityName then cityName.Text = "Nothing" end

	local collection = ui:FindFirstChild("CollectIncome")
	local button = collection and collection:FindFirstChild("Button")
	local buttonInfo = button and button:FindFirstChild("ButtonInfo")
	if button and button:IsA("BasePart") then
		button.Color = Color3.fromRGB(218, 218, 218)
		button.Transparency = 0.6
	end
	if buttonInfo then buttonInfo.Enabled = false end

	local ratioSign = ui:FindFirstChild("RatioSign")
	if ratioSign then
		for _, child in ratioSign:GetDescendants() do
			if child:IsA("LayerCollector") or child:IsA("ProximityPrompt") then
				child.Enabled = false
			end
		end
	end
end
