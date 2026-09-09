local Audio = require(script.Audio)
local Codes = require(script.Codes)
local SoundService = game:GetService("SoundService")
return function(Context)
	local cleanupAudio
	function Context.setupSettingsControls()
		if cleanupAudio then
			cleanupAudio()
		end
		cleanupAudio = Audio.bind(Context.State.SettingsFrame, Context.connections, SoundService, Context.TweenService)
		Codes.bind(
			Context.State.SettingsFrame,
			Context.connections,
			Context.ReplicatedStorage.Events.UI.CodeFeeback,
			SoundService
		)
	end
	function Context.cleanupSettingsControls()
		if cleanupAudio then
			cleanupAudio()
			cleanupAudio = nil
		end
	end
end
