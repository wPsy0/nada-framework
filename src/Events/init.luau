--!strict
local Network = require(script.Network)
local Guard = require(script.Network.Guard)

const TestEvent: Network.Event<string, number> = Network.Define("TestEvent", {
    Guard.StringMax(24),
    Guard.Integer(0, 99)
}, {
    unreliable = false,
    middlewares = {
        Network.RateLimit(12)
    }
})

return {
    TestEvent = TestEvent
}