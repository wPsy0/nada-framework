# N.A.D.A Framework (Not Another Dumb Architecture)

A tiny, strictly-typed framework for Roblox. Nothing you don't need.

No proxies, no reflection, no magic: just small modules you can read in one sitting.

## Features

- **Strict Luau** everywhere (`--!strict`).
- **Typed networking.** Define an event once, share the same payload types on client and server.
- **Composable validation.** Server-side payload checks built from small `Guard` validators.
- **Middlewares.** Rate limits, permissions or round-state checks run before your handler.
- **Services with a shared side.** Each service exposes its utilities and events from a single shared module.
- **Utilities.** A folder of small, standalone modules (signals, and more to come) usable from any environment.

## Project layout

The layout is defined in `default.project.json` and mapped with [Rojo](https://rojo.space).

### In the repository

```
src
├── Core
│   ├── Boot
│   │   ├── Shared
│   │   ├── Server
│   │   └── Client
│   ├── Network
│   └── Utilities
└── Services
    ├── Shared
    ├── Server
    └── Client
```

### In Roblox

```
ReplicatedStorage
├── Boot                  -- shared bootstrap code       (src/Core/Boot/Shared)
├── Network               -- Network + Guard             (src/Core/Network)
├── Utilities             -- standalone helper modules   (src/Core/Utilities)
└── Shared
    └── Services
        └── TestService   -- utilities + events, used by both sides

ServerScriptService
├── Server                -- server entry point          (src/Core/Boot/Server)
└── Services
    └── TestService       -- server logic

StarterPlayer
└── StarterPlayerScripts
    ├── Client            -- client entry point          (src/Core/Boot/Client)
    └── Services
        └── TestService   -- client logic
```

Each service exists in up to three environments, all named after the service. A service only needs the sides it actually uses.

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

## Networking

### Defining events

`Network.Define(name, guards, options)` creates an event. One guard per argument, in order. Names are unique, so namespacing them as `"Service/Event"` keeps things tidy.

```luau
-- Several arguments, an optional one, and an unreliable event for high-frequency data
local Moved: Network.Event<Vector3, number?> = Network.Define("Movement/Moved", {
	Guard.Vector3,
	Guard.Optional(Guard.Range(0, 1)),
}, {
	unreliable = true,
})
```

### Firing events

| Direction | Send | Receive |
| --- | --- | --- |
| Client → Server | `FireServer(...)` | `OnServerEvent(function(player, ...) end)` |
| Server → Client | `FireClient(player, ...)` | `OnClientEvent(function(...) end)` |

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

Guards compose, so complex payloads stay readable:

```luau
local Purchase: Network.Event<{ ItemId: string, Amount: number }> = Network.Define("Shop/Purchase", {
	Guard.Object({
		ItemId = Guard.StringMax(32),
		Amount = Guard.Integer(1, 99),
	}),
})

-- An array of up to 10 instances of a class
local Targets = Guard.Array(Guard.Instance("BasePart"), 10)

-- Same value passing through several checks
local Percent = Guard.All(Guard.Number, Guard.Range(0, 100))
```

## Middlewares

Middlewares run before validation and can stop an event early. They have the same signature everywhere, so cooldowns, role checks or round-state checks plug in without touching the core:

```luau
local Middleware = (player: Player, ...unknown) -> boolean
```

Return `true` to let the event continue, `false` to drop it.

```luau
-- Only players inside a round can send this event
local function inRound(player: Player): boolean
	return player:GetAttribute("InRound") == true
end

-- Only admins
local ADMINS = { [1] = true }
local function isAdmin(player: Player): boolean
	return ADMINS[player.UserId] == true
end

local Kick: Network.Event<Player> = Network.Define("Admin/Kick", {
	Guard.Instance("Player"),
}, {
	middlewares = { isAdmin, Network.RateLimit(2) },
})
```

Middlewares run in order and the first one that returns `false` stops the chain, so put cheap checks first.

## Utilities

`ReplicatedStorage.Utilities` holds small, standalone modules. They don't depend on the networking layer or on services, so they work on both server and client, and you can use them in any project.

```luau
local Utilities = ReplicatedStorage.Utilities
local Signal = require(Utilities.Signal)
```

### Signal

A typed signal with `Connect`, `Once`, `Wait`, interceptors (filters that can cancel an event before listeners run) and `Destroy`.

```luau
local Signal = require(ReplicatedStorage.Utilities.Signal)

local Damaged: Signal.Signal<number, string> = Signal.new()

-- Connect returns a Connection
local connection = Damaged:Connect(function(amount, source)
	print(`took {amount} from {source}`)
end)

-- Fire once, then stop listening
Damaged:Once(function(amount)
	print("first hit:", amount)
end)

-- Yield until the next fire
local amount, source = Damaged:Wait()

-- Interceptors: return true to let the event through, false to cancel it
Damaged:AddInterceptor(function(amount)
	return amount > 0
end)

Damaged:Fire(25, "Zombie")

connection:Disconnect()
Damaged:Destroy()
```

### Planned utilities

The same rules apply to everything that joins `Utilities`: strict types, no magic, small enough to read in one sitting.

| Utility | Purpose |
| --- | --- |
| `Cleaner` | Track connections, instances, threads and functions, and clean them all up at once |
| `Promise` | Typed promises for async flows, chaining and error handling |
| `Timer` | Cooldowns, intervals and delays with clean cancellation |
| `Pool` | Object and thread pooling for hot paths |
| `State` | Small observable values with change signals |

Nothing here is final. If a utility isn't needed by a real project, it doesn't get written.

## Design notes

- **Simplicity over features.** The whole networking layer is two small modules.
- **Types are declared, not inferred.** Luau can't derive `Event<number, string>` from a list of guards, so the annotation is written by hand next to the `Define` call.
- **No serialization.** Payloads travel the way Roblox sends them by default. For most games that's fine; for very high-frequency events with many players, a buffer-based approach would use less bandwidth.
- **Utilities stay independent.** Each utility is a single module with no dependencies on the rest of the framework, so it can be copied elsewhere as is.