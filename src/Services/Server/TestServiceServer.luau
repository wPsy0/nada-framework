--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestServiceShared = require(ReplicatedStorage.Shared.TestServiceShared)
local Events = require(ReplicatedStorage.Events)

local TestServiceServer = {}

function TestServiceServer.Init(self: TestServiceServer): ()
    TestServiceShared.Salute("TestServiceServer", "Init")
    Events.TestEvent.OnServerEvent(function(player: Player, name: string, age: number)
        print(`Hello {name}! congrats on being {age}!`)
    end)
end

function TestServiceServer.Start(self: TestServiceServer): ()
    TestServiceShared.Salute("TestServiceServer", "Start")
end

export type TestServiceServer = typeof(TestServiceServer)

return TestServiceServer