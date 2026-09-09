local Camera = {}
function Camera.start(session, services)
	local workspace = services.Workspace
	local blur = services.Lighting:FindFirstChild("Blur")
	if blur and not blur:IsA("BlurEffect") then
		blur = nil
	end
	local createdBlur = not blur
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "MyCityIntroBlur"
		blur.Parent = services.Lighting
	end
	local saved = {
		cameras = {},
		roots = {},
		blur = blur,
		blurSize = blur.Size,
		createdBlur = createdBlur,
		workspace = workspace,
		player = services.player,
	}
	session.cameraState = saved
	local angle = 0
	local function update(dt)
		-- Character, camera and streamed map can arrive after the loading screen.
		local root = services.player.Character and services.player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			if saved.roots[root] == nil then
				saved.roots[root] = root.Anchored
			end
			root.Anchored = true
		end
		blur.Size = 12
		local map = workspace:FindFirstChild("Map")
		local target = map and map:FindFirstChild("SpawnCam")
		local camera = workspace.CurrentCamera
		if not camera or not target or not target:IsA("BasePart") then
			return
		end
		if not saved.cameras[camera] then
			saved.cameras[camera] = { kind = camera.CameraType, subject = camera.CameraSubject, cframe = camera.CFrame }
		end
		angle += 0.024 * dt
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(
			target.Position + Vector3.new(math.cos(angle) * 50, 10, math.sin(angle) * 50),
			target.Position
		)
	end
	update(0)
	session.scope:connect(services.RunService.RenderStepped, update)
end
function Camera.restore(session, success)
	local saved = session.cameraState
	session.cameraState = nil
	if not saved then
		return
	end
	for root, anchored in saved.roots do
		if root.Parent then
			root.Anchored = anchored
		end
	end
	for camera, original in saved.cameras do
		if success then
			camera.CameraType = Enum.CameraType.Custom
			local character = saved.player.Character
			camera.CameraSubject = (character and character:FindFirstChild("Humanoid")) or original.subject
		else
			camera.CameraType = original.kind
			camera.CameraSubject = original.subject
			camera.CFrame = original.cframe
		end
	end
	-- Also handle a camera replaced just as Play completes.
	if success and saved.workspace.CurrentCamera then
		local camera = saved.workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = saved.player.Character and saved.player.Character:FindFirstChild("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	if saved.createdBlur then
		saved.blur:Destroy()
	elseif saved.blur.Parent then
		saved.blur.Size = if success then 0 else saved.blurSize
	end
end
return Camera
