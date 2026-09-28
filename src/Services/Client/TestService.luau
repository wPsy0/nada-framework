--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestServiceShared = require(ReplicatedStorage.Shared.Services.TestService)

local TestService = {}

function TestService.Start(): ()
	TestServiceShared.Events.TestEvent.OnClientEvent(function(id, message)
		-- id: number, message: string
		TestServiceShared.Salute("server", message)
	end)

	TestServiceShared.Events.TestEvent.FireServer(42, "hello")
end

return TestService