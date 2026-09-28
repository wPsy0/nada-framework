--!strict
export type Check = (value: unknown) -> boolean

local Guard = {}

local function isFiniteNumber(v: unknown): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

Guard.Number = isFiniteNumber :: Check -- rechaza NaN e inf

Guard.String = function(v: unknown): boolean
	return typeof(v) == "string"
end :: Check

Guard.Boolean = function(v: unknown): boolean
	return typeof(v) == "boolean"
end :: Check

Guard.Vector3 = function(v: unknown): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	return isFiniteNumber(vec.X) and isFiniteNumber(vec.Y) and isFiniteNumber(vec.Z)
end :: Check

Guard.Integer = function(min: number?, max: number?): Check
	return function(v: unknown): boolean
		if not isFiniteNumber(v) then
			return false
		end
		local n = v :: number
		return n % 1 == 0 and (min == nil or n >= min) and (max == nil or n <= max)
	end
end

Guard.Range = function (min: number, max: number): Check
	return function(v: unknown): boolean
		return isFiniteNumber(v) and (v :: number) >= min and (v :: number) <= max
	end
end

Guard.StringMax = function(maxLen: number): Check
	return function(v: unknown): boolean
		return typeof(v) == "string" and #(v :: string) <= maxLen
	end
end

Guard.Instance = function(className: string): Check
	return function(v: unknown): boolean
		return typeof(v) == "Instance" and (v :: Instance):IsA(className)
	end
end

Guard.OneOf = function(...: unknown): Check
	local set: { [unknown]: boolean } = {}
	for _, value in { ... } do
		set[value] = true
	end
	return function(v: unknown): boolean
		return set[v] == true
	end
end

Guard.Optional = function(check: Check): Check
	return function(v: unknown): boolean
		return v == nil or check(v)
	end
end

Guard.All = function(...: Check): Check
	local checks = { ... }
	return function(v: unknown): boolean
		for _, check in checks do
			if not check(v) then
				return false
			end
		end
		return true
	end
end

Guard.Array = function(check: Check, maxLen: number): Check
	return function(v: unknown): boolean
		if typeof(v) ~= "table" then
			return false
		end
		local t = v :: { [any]: any }
		local len = #t
		if len > maxLen then
			return false
		end
		local total = 0
		for _ in t do
			total += 1
		end
		if total ~= len then -- keys no secuenciales
			return false
		end
		for i = 1, len do
			if not check(t[i]) then
				return false
			end
		end
		return true
	end
end

Guard.Object = function(shape: { [string]: Check }): Check
	return function(v: unknown): boolean
		if typeof(v) ~= "table" then
			return false
		end
		local t = v :: { [any]: any }
		for key, check in shape do
			if not check(t[key]) then
				return false
			end
		end
		for key in t do -- rechaza claves extra
			if shape[key] == nil then
				return false
			end
		end
		return true
	end
end

return Guard