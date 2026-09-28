--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guard = require(script.Guard)

local IS_SERVER = RunService:IsServer()
local IS_STUDIO = RunService:IsStudio()

export type Middleware = (player: Player, ...unknown) -> boolean

export type Options = {
	unreliable: boolean?,
	middlewares: { Middleware }?,
}

export type Event<T...> = {
	Name: string,
	FireServer: (T...) -> (),
	FireClient: (player: Player, T...) -> (),
	FireAllClients: (T...) -> (),
	OnServerEvent: (fn: (player: Player, T...) -> ()) -> RBXScriptConnection,
	OnClientEvent: (fn: (T...) -> ()) -> RBXScriptConnection,
}

local Network = {}

local remotesFolder: Folder
if IS_SERVER then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
else
	remotesFolder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local declared: { [string]: boolean } = {}

local function getRemote(name: string, unreliable: boolean?): any
	if IS_SERVER then
		assert(not declared[name], `[NADA] Event "{name}" already defined`)
		declared[name] = true

		local remote: any = if unreliable then Instance.new("UnreliableRemoteEvent") else Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
		return remote
	end
	return remotesFolder:WaitForChild(name)
end

local function validate(guards: { Guard.Check }, ...: unknown): boolean
	if select("#", ...) > #guards then
		return false
	end
	for i, check in guards do
		if not check((select(i, ...))) then
			return false
		end
	end
	return true
end

function Network.Define<T...>(name: string, guards: { Guard.Check }, options: Options?): Event<T...>
	local opts: Options = options or {}
	local middlewares = opts.middlewares
	local remote = getRemote(name, opts.unreliable)

	local event = {
		Name = name,

		FireServer = function(...: any)
			assert(not IS_SERVER, "[NADA] FireServer is only callable on the client")
			if IS_STUDIO then
				assert(validate(guards, ...), `[NADA] {name}: invalid payload in FireServer`)
			end
			remote:FireServer(...)
		end,

		FireClient = function(player: Player, ...: any)
			assert(IS_SERVER, "[NADA] FireClient is only callable on the server")
			remote:FireClient(player, ...)
		end,

		FireAllClients = function(...: any)
			assert(IS_SERVER, "[NADA] FireAllClients is only callable on the server")
			remote:FireAllClients(...)
		end,

		OnServerEvent = function(fn: (Player, ...any) -> ()): RBXScriptConnection
			assert(IS_SERVER, "[NADA] OnServerEvent is only callable on the server")
			return remote.OnServerEvent:Connect(function(player: Player, ...: any)
				-- primero lo barato: rate limit, permisos, etc.
				if middlewares then
					for _, middleware in middlewares do
						if not middleware(player, ...) then
							return
						end
					end
				end

				if not validate(guards, ...) then
					if IS_STUDIO then
						warn(`[NADA] {name}: payload rejected from {player.Name}`)
					end
					return
				end

				fn(player, ...)
			end)
		end,

		OnClientEvent = function(fn: (...any) -> ()): RBXScriptConnection
			assert(not IS_SERVER, "[NADA] OnClientEvent is only callable on the client")
			return remote.OnClientEvent:Connect(fn)
		end,
	}

	return event :: any
end

-- Ejemplo de middleware reutilizable
function Network.RateLimit(maxPerSecond: number): Middleware
	local buckets: { [Player]: { count: number, windowStart: number } } = setmetatable({}, { __mode = "k" }) :: any

	return function(player: Player, ...: unknown): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket or now - bucket.windowStart >= 1 then
			buckets[player] = { count = 1, windowStart = now }
			return true
		end
		bucket.count += 1
		return bucket.count <= maxPerSecond
	end
end

return Network