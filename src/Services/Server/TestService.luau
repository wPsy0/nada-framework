--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestServiceShared = require(ReplicatedStorage.Shared.Services.TestService)

local TestService = {}

function TestService.Start(): ()
	TestServiceShared.Events.TestEvent.OnServerEvent(function(player, id, message)
		-- player: Player, id: number, message: string
		-- payload already validated, rate limit already applied
		TestServiceShared.Salute(player.Name, message)
		TestServiceShared.Events.TestEvent.FireClient(player, id, message)
	end)
end

return TestService