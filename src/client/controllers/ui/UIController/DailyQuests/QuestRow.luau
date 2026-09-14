local Style = require(script.Parent.ClaimStyle)
local Row = {}
local colors =
	{ Easy = Color3.fromRGB(48, 156, 88), Medium = Color3.fromRGB(189, 128, 25), Hard = Color3.fromRGB(194, 73, 77) }
local function number(value)
	local amount = tostring(math.floor(value))
	return amount:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function find(root, name, class)
	for _, child in root:GetChildren() do
		if child.Name == name and child:IsA(class) then
			return child
		end
	end
	return nil
end
function Row.create(template, parent, callback)
	local root = template:Clone()
	local track = find(root, "Progress", "Frame")
	local claim = find(root, "Claim", "GuiButton")
	local difficulties = {}
	for _, child in root:GetChildren() do
		if child.Name == "Difficulty" and child:IsA("TextLabel") then
			table.insert(difficulties, child)
		end
	end
	local self = {
		Root = root,
		Title = find(root, "Title", "TextLabel"),
		Difficulty = difficulties[1],
		Difficulties = difficulties,
		Progress = find(root, "Progress", "TextLabel"),
		Reward = find(root, "Reward", "TextLabel"),
		Fill = track and track:FindFirstChild("Fill"),
		Claim = claim,
		ClaimText = claim and (claim:FindFirstChild("TextLabel", true) or claim),
		ClaimBackground = claim and claim.BackgroundColor3,
	}
	if not (self.Title and self.Difficulty and self.Progress and self.Reward and self.Fill and self.Claim) then
		root:Destroy()
		error("[DailyQuests] Template needs Title/Difficulty/Reward/Progress labels, Progress (Frame).Fill and Claim")
	end
	if self.ClaimText ~= claim and claim:IsA("TextButton") then
		claim.Text = ""
	end
	root:SetAttribute("MyCityQuestRow", true)
	root.Visible = true
	root.Parent = parent
	self.connection = claim.Activated:Connect(function()
		if self.ready then
			callback(self.id)
		end
	end)
	Row.loading(self)
	return self
end
function Row.loading(self)
	self.ready = false
	self.Title.Text, self.Difficulty.Text, self.Progress.Text = "Loading quest...", "", "-- / --"
	for _, label in self.Difficulties do
		label.Text = ""
	end
	if self.Reward then
		self.Reward.Text = ""
	end
	self.Fill.Size = UDim2.fromScale(0, 1)
	Style.apply(self, "Loading...", false)
end
function Row.update(self, quest, order, tweenService, pending)
	self.id = quest.Id
	self.Root.Name, self.Root.LayoutOrder = "Quest" .. order, order
	self.Title.Text = quest.Title
	for _, label in self.Difficulties do
		label.Text, label.TextColor3 = quest.Difficulty, colors[quest.Difficulty]
	end
	local progress, target = quest.Progress, quest.Target
	if quest.Metric == "play" then
		self.Progress.Text = string.format("%.1f / %d min", progress / 60, target / 60)
	else
		self.Progress.Text = number(progress) .. " / " .. number(target)
	end
	self.Reward.Text = "+$" .. number(quest.Reward)
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
	Style.apply(
		self,
		if quest.Claimed
			then "Claimed"
			elseif pending then "Claiming..."
			elseif self.ready then "Claim"
			else "Locked",
		self.ready
	)
end
function Row.destroy(self)
	if self.tween then
		self.tween:Cancel()
	end
	self.connection:Disconnect()
	self.Root:Destroy()
end
return Row
