# N.A.D.A Framework (Not Another Dumb Architecture)

A tiny, strictly-typed framework for Roblox. Nothing you don't need.

No proxies, no reflection, no magic: just small modules you can read in one sitting.

## Features

- **Strict Luau** everywhere (`--!strict`).
- **Typed networking.** Define an event once, share the same payload types on client and server.
- **Composable validation.** Server-side payload checks built from small `Guard` validators.
- **Middlewares.** Rate limits, permissions or round-state checks run before your handler.
- **Services with a shared side.** Each service exposes its utilities and events from a single shared module.

## Project layout

`Network` lives in `ReplicatedStorage`. Each service exists in up to three environments, all named after the service:

```
ReplicatedStorage
├── Network            -- Network + Guard
└── Shared
    └── Services
        └── TestService   -- utilities + events, used by both sides
Server
└── Services
    └── TestService       -- server logic
Client
└── Services
    └── TestService       -- client logic
```

## Quick look: TestService

### Shared

The shared module exposes the service's utilities and its events. The payload type and the guards live side by side:

```luau
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
```

### Server

```luau
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
```

### Client

```luau
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
```

## Validation

Everything coming from the client is untrusted, so validation happens on the server before your handler runs. In Studio, `FireServer` also validates before sending, so mistakes surface on the side that caused them.

Built-in guards:

| Guard | Accepts |
| --- | --- |
| `Guard.Number` | finite numbers (rejects `NaN` and `inf`) |
| `Guard.String`, `Guard.Boolean` | the obvious |
| `Guard.Vector3` | `Vector3` with finite components |
| `Guard.Integer(min?, max?)` | integers in range |
| `Guard.Range(min, max)` | numbers in range |
| `Guard.StringMax(n)` | strings up to `n` characters |
| `Guard.Instance(className)` | instances of a class |
| `Guard.OneOf(...)` | any of the listed values |
| `Guard.Optional(check)` | `nil` or a valid value |
| `Guard.All(...)` | every check passes |
| `Guard.Array(check, maxLen)` | bounded arrays |
| `Guard.Object(shape)` | tables with exactly this shape |

A guard is just `(unknown) -> boolean`, so writing your own takes one function:

```luau
local isPositive: Guard.Check = function(v)
	return typeof(v) == "number" and v > 0
end
```

## Middlewares

Middlewares run before validation and can stop an event early. They have the same signature everywhere, so cooldowns, role checks or round-state checks plug in without touching the core:

```luau
local Middleware = (player: Player, ...unknown) -> boolean
```

## Design notes

- **Simplicity over features.** The whole networking layer is two small modules.
- **Types are declared, not inferred.** Luau can't derive `Event<number, string>` from a list of guards, so the annotation is written by hand next to the `Define` call.
- **No serialization.** Payloads travel the way Roblox sends them by default. For most games that's fine; for very high-frequency events with many players, a buffer-based approach would use less bandwidth.