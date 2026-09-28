--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestServiceShared = require(ReplicatedStorage.Shared.TestServiceShared)

local TestServiceClient = {}

function TestServiceClient.Init(self: TestServiceClient): ()
    TestServiceShared.Salute("TestServiceClient", "Init")
    ContextActionService:BindAction("TestAction", function(
        actionName: string, 
        inputState: Enum.UserInputState, 
        inputObject: InputObject
    ): Enum.ContextActionResult?
        if inputState == Enum.UserInputState.Begin then
            TestServiceShared.Events.TestEvent.FireServer("David", 17)
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.E)
end

function TestServiceClient.Start(self: TestServiceClient): ()
    TestServiceShared.Salute("TestServiceClient", "Start")
end

export type TestServiceClient = typeof(TestServiceClient)

return TestServiceClient