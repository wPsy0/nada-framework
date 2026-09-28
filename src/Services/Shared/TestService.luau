--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Network)
local Guard = require(ReplicatedStorage.Network.Guard)

local TestEvent: Network.Event<number, string> = Network.Define("Test/Event", {
	Guard.Integer(0, 99),
	Guard.StringMax(24),
}, {
	middlewares = { Network.RateLimit(12) },
	unreliable = false,
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