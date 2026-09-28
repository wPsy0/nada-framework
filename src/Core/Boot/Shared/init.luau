--!strict
local Boot = {}

function Boot.BootChildren(dir: Folder, ...): ()
    local mod = {}
    for _, v in dir:GetChildren() do
        local success, resultOrErr = pcall(require, v)
        if success then
            table.insert(mod, resultOrErr)
            continue
        end
        warn(resultOrErr)
    end

    local var = {...}
    local k, v = next(var)
    while k do
        for _, j in mod do
            local fn = j[v]
            if typeof(fn) == "function" then
                local success, resultOrErr = pcall(fn, j)
                if success then
                    continue
                end
                warn(`[NADA] {resultOrErr}`)
            end
        end
        k, v = next(var, k)
    end
end

return Boot