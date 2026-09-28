--!strict
local TestServiceShared = {}

function TestServiceShared.Salute(from: string, to: string): ()
    print(`{from} -> {to}`)
end

return TestServiceShared