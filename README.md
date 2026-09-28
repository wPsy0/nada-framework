# nada-framework

A tiny, strictly-typed framework for Roblox. Nothing you don't need.

No proxies, no reflection, no magic: just small modules you can read in one sitting.

## Features

- **Strict Luau** everywhere (`--!strict`).
- **Typed networking.** Define an event once, share the same payload types on client and server.
- **Composable validation.** Server-side payload checks built from small `Guard` validators.
- **Middlewares.** Rate limits, permissions or round-state checks run before your handler.
- **One place per feature.** Each feature declares its events in a single shared module.

## Quick look

Declare events in a shared module. The type and the guards live side by side:

```luau
--!strict
local Network = require(Shared.Network)
local Guard = require(Shared.Guard)

local Attack: Network.Event<number, Vector3> = Network.Define("Combat/Attack", {
	Guard.Range(0, 100),
	Guard.Vector3,
}, {
	middlewares = { Network.RateLimit(10) },
    unreliable = false
})

return {
	Attack = Attack,
}
```

Server:

```luau
local CombatEvents = require(Shared.Events.Combat)

CombatEvents.Attack.OnServerEvent(function(player, damage, direction)
	-- player: Player, damage: number, direction: Vector3
	-- payload already validated, rate limit already applied
end)
```

Client:

```luau
local CombatEvents = require(Shared.Events.Combat)

CombatEvents.Attack.FireServer(25, Vector3.new(0, 0, 1))
```

## Validation

Everything coming from the client is untrusted, so validation happens on the server before your handler runs. In Studio, `FireServer` also validates before sending, so mistakes surface on the side that caused them.

Built-in guards:

| Guard | Accepts |
| --- | --- |
| `Guard.Number` | finite numbers (rejects `NaN` and `inf`) |
| `Guard.String`, `Guard.boolean` | the obvious |
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
- **Types are declared, not inferred.** Luau can't derive `Event<number, Vector3>` from a list of guards, so the annotation is written by hand next to the `Define` call.
- **No serialization.** Payloads travel the way Roblox sends them by default. For most games that's fine; for very high-frequency events with many players, a buffer-based approach would use less bandwidth.