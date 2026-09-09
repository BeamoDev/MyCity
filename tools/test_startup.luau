-- Execute only the client initializer with mock services/controllers.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function node(children)
	children = children or {}
	function children:WaitForChild(name)
		return assert(self[name], "Unexpected or missing child: " .. name)
	end
	return children
end

local function scenario(initiallyReady, initialTutorial, finalTutorial)
	local calls = {}
	local hud = node({ Frames = {}, Buttons = {}, Destroying = { Connect = function() end } })
	local status = { Value = initialTutorial }
	local ready = initiallyReady
	local player = node({
		Data = node({ PlayerInfo = node({ Tutorial = node({ IsInTutorial = status }) }) }),
		leaderstats = {},
	})
	function player:GetAttribute(name)
		assert(name == "MyCityLoaded")
		return ready
	end
	function player:GetAttributeChangedSignal(name)
		assert(name == "MyCityLoaded")
		return {
			Wait = function()
				coroutine.yield("waiting for server")
			end,
		}
	end
	local modules = node({
		Network = { wait = function() end },
		UIEffects = {
			ApplyToAll = function(gui)
				assert(gui == hud)
				calls.effects = (calls.effects or 0) + 1
			end,
		},
	})
	for _, name in
		{
			"UIController",
			"NotificationController",
			"ShopController",
			"TutorialController",
			"SellController",
			"FriendsBoost",
			"LikeSystem",
		}
	do
		modules[name] = {
			moduleName = name,
			init = function(gui)
				assert(gui == hud)
				calls[name] = (calls[name] or 0) + 1
			end,
		}
	end
	modules.NotificationController.prepare = function() end
	modules.NotificationController.flush = function()
		assert(calls.released, "Notifications shown behind intro")
	end
	modules.UIController.initRebirthSystem = function()
		calls.rebirth = (calls.rebirth or 0) + 1
	end
	modules.UIController.setupNormalUI = function()
		calls.normal = (calls.normal or 0) + 1
	end
	modules.TutorialController.startTutorial = function()
		error("Tutorial init already starts the tutorial")
	end
	local replicated = node({
		shared = node({ Network = modules.Network, UIEffects = modules.UIEffects }),
		Events = {
			Loading = {
				IntroFinished = {
					FireServer = function()
						assert(calls.released)
						calls.introFinished = true
					end,
				},
				ClientReady = {
					FireServer = function()
						calls.ready = true
					end,
				},
			},
		},
	})
	local services = { Players = { LocalPlayer = player }, ReplicatedStorage = replicated }
	local init = luau.load(fs.readFile("src/client/bootstrap/HudBootstrap.luau"), {
		environment = {
			script = {
				Parent = {
					EarlyLoading = {
						finish = function()
							assert(
								calls.TutorialController or calls.normal,
								"Inventory released before tutorial/UI setup"
							)
							calls.released = true
						end,
					},
					Parent = node({
						controllers = node({
							ui = modules,
							shop = modules,
							tutorial = modules,
							social = modules,
							intro = node({
								IntroController = {
									run = function()
										assert(
											not calls.UIController,
											"Intro must run before gameplay/data-dependent initialization"
										)
										calls.playCompleted = true
										return true
									end,
									cleanup = function() end,
								},
							}),
						}),
					}),
				},
			},
			game = {
				GetService = function(_, name)
					return assert(services[name])
				end,
			},
			require = function(module)
				if module.moduleName and module.moduleName ~= "NotificationController" then
					assert(calls.playCompleted, "Gameplay module required before intro completed")
				end
				return module
			end,
		},
	})()
	local thread = coroutine.create(function()
		init.initialize(hud)
	end)
	local ok, err = coroutine.resume(thread)
	assert(ok, err)
	assert(calls.UIController == 1 and calls.rebirth == 1, "UI listeners must bind before readiness wait")
	init.initialize(hud)
	assert(calls.UIController == 1 and calls.effects == 1, "Duplicate startup initialized the HUD twice")
	if not initiallyReady then
		assert(coroutine.status(thread) == "suspended")
		assert(not calls.normal and not calls.TutorialController, "Gameplay UI started before the plot was ready")
		status.Value = finalTutorial
		ready = true
		ok, err = coroutine.resume(thread)
		assert(ok, err)
	end
	assert(coroutine.status(thread) == "dead")
	if status.Value then
		assert(calls.TutorialController == 1 and not calls.normal)
	else
		assert(calls.normal == 1 and not calls.TutorialController)
	end
end

scenario(true, false, false)
scenario(true, true, true)
scenario(false, true, false)
scenario(false, true, true)
print(
	"PASS: 4 startup scenarios (late client, tutorial, delayed server, changed tutorial state); duplicate initialization suppressed"
)
