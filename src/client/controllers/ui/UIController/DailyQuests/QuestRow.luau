local W = require(script.Parent.Widgets)
local Row = {}
local colors =
	{ Easy = Color3.fromRGB(48, 156, 88), Medium = Color3.fromRGB(189, 128, 25), Hard = Color3.fromRGB(194, 73, 77) }
function Row.create(parent, callback)
	local root = W.make(
		"Frame",
		parent,
		{ Size = UDim2.new(1, 0, 0, 148), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }
	)
	W.corner(root, 10)
	W.make("UIStroke", root, { Color = Color3.fromRGB(214, 219, 205), Thickness = 1 })
	local title = W.text(root, "", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 43), 17)
	local difficulty = W.text(root, "", UDim2.fromOffset(12, 52), UDim2.new(0.4, 0, 0, 21), 13)
	local progress = W.text(root, "", UDim2.new(0.4, 0, 0, 52), UDim2.new(0.6, -12, 0, 21), 13)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	local track = W.make("Frame", root, {
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.fromRGB(230, 234, 224),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	W.corner(track, 6)
	local fill = W.make(
		"Frame",
		track,
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(85, 195, 91), BorderSizePixel = 0 }
	)
	W.corner(fill, 6)
	local reward =
		W.text(root, "", UDim2.fromOffset(12, 105), UDim2.new(1, -139, 0, 32), 16, Color3.fromRGB(36, 137, 64))
	local claim = W.make("TextButton", root, {
		Position = UDim2.new(1, -118, 0, 103),
		Size = UDim2.fromOffset(106, 34),
		Text = "In progress",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(135, 142, 143),
		BorderSizePixel = 0,
	})
	W.corner(claim, 8)
	local self = {
		Root = root,
		Title = title,
		Difficulty = difficulty,
		Progress = progress,
		Reward = reward,
		Fill = fill,
		Claim = claim,
	}
	self.connection = claim.Activated:Connect(function()
		if self.ready then
			callback(self.id)
		end
	end)
	return self
end
function Row.update(self, quest, order, tweenService, pending)
	self.id = quest.Id
	self.Root.Name, self.Root.LayoutOrder = quest.Id, order
	self.Title.Text = quest.Title
	self.Difficulty.Text, self.Difficulty.TextColor3 = quest.Difficulty, colors[quest.Difficulty]
	local progress, target = quest.Progress, quest.Target
	if quest.Metric == "play" then
		self.Progress.Text = string.format("%.1f / %d min", progress / 60, target / 60)
	else
		self.Progress.Text = W.number(progress) .. " / " .. W.number(target)
	end
	self.Reward.Text = "+$" .. W.number(quest.Reward)
	local fraction = math.clamp(progress / math.max(1, target), 0, 1)
	if fraction ~= self.fraction then
		self.fraction = fraction
		if self.tween then
			self.tween:Cancel()
		end
		self.tween = tweenService:Create(self.Fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(fraction, 1) })
		self.tween:Play()
	end
	self.ready = not quest.Claimed and progress >= target and not pending
	self.Claim.Text = if quest.Claimed
		then "Claimed"
		elseif pending then "Claiming?"
		elseif self.ready then "Claim"
		else "In progress"
	self.Claim.BackgroundColor3 = if self.ready then Color3.fromRGB(50, 169, 81) else Color3.fromRGB(135, 142, 143)
	self.Claim.AutoButtonColor, self.Claim.Interactable = self.ready, self.ready
end
function Row.destroy(self)
	if self.tween then
		self.tween:Cancel()
	end
	self.connection:Disconnect()
	self.Root:Destroy()
end
return Row
