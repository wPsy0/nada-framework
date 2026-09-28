--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Network)
local Guard = require(ReplicatedStorage.Network.Guard)

local TestEvent: Network.Event<string, number> = Network.Define("Test/Event", {
	Guard.StringMax(24),
	Guard.Integer(0, 99),
}, {
	middlewares = { Network.RateLimit(12) },
})

local function salute(from: string, to: string): ()
	print(`{from} -> {to}`)
end

return {
	Salute = salute,
	Events = {
		TestEvent = TestEvent,
	},
}