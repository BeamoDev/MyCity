local Style = {}
local greenStroke = Color3.fromRGB(31, 106, 40)
local green = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(68, 255, 11)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(174, 255, 69)),
})
local greyStroke = Color3.fromRGB(80, 80, 80)
local grey = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 130, 130)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 185)),
})
function Style.apply(row, text, enabled)
	local button = row.Claim
	row.ClaimText.Text = text
	button.Active, button.Interactable, button.AutoButtonColor = enabled, enabled, enabled
	button.BackgroundColor3 = if enabled then row.ClaimBackground else Color3.fromRGB(160, 160, 160)
	for _, item in button:GetDescendants() do
		if item:IsA("UIStroke") then
			item.Color = if enabled then greenStroke else greyStroke
		elseif item:IsA("UIGradient") then
			item.Color = if enabled then green else grey
		end
	end
end
return Style
