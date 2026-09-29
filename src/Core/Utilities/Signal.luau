--!strict

type SignalCallback<T...> = (T...) -> ()

export type SignalConnection = {
    Disconnect: (self: SignalConnection) -> (),
}

export type SignalInterceptor<T...> = (T...) -> boolean

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable({} :: {
    _SignalListeners: {SignalCallback<T...>},
    _SignalInterceptors: {SignalInterceptor<T...>},
}, Signal))

local function withAdded<V>(list: {V}, value: V): {V}
    local new = table.clone(list)
    table.insert(new, value)
    return new
end

local function withRemoved<V>(list: {V}, value: V): {V}
    local index = table.find(list, value)
    if not index then
        return list
    end
    local new = table.clone(list)
    table.remove(new, index)
    return new
end

function Signal.new<T...>(interceptors: {SignalInterceptor<T...>}?): Signal<T...>
    return setmetatable({
        _SignalListeners = {},
        _SignalInterceptors = if interceptors then table.clone(interceptors) else {},
    }, Signal)
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
    for _, interceptor in self._SignalInterceptors do
        if not interceptor(...) then
            return
        end
    end

    for _, listener in self._SignalListeners do
        task.spawn(listener, ...)
    end
end

function Signal.Connect<T...>(self: Signal<T...>, fn: SignalCallback<T...>): SignalConnection
    self._SignalListeners = withAdded(self._SignalListeners, fn)

    local connected = true

    return {
        Disconnect = function(_: SignalConnection): ()
            if not connected then
                return
            end
            connected = false
            self._SignalListeners = withRemoved(self._SignalListeners, fn)
        end,
    }
end

function Signal.Once<T...>(self: Signal<T...>, fn: SignalCallback<T...>): SignalConnection
    local connection: SignalConnection
    connection = self:Connect(function(...: T...)
        connection:Disconnect()
        fn(...)
    end)
    return connection
end

function Signal.Wait<T...>(self: Signal<T...>): T...
    local thread = coroutine.running()
    self:Once(function(...: T...)
        task.spawn(thread, ...)
    end)
    return (coroutine.yield :: () -> T...)()
end

function Signal.AddInterceptor<T...>(self: Signal<T...>, interceptor: SignalInterceptor<T...>): SignalConnection
    self._SignalInterceptors = withAdded(self._SignalInterceptors, interceptor)

    local active = true

    return {
        Disconnect = function(_: SignalConnection): ()
            if not active then
                return
            end
            active = false
            self._SignalInterceptors = withRemoved(self._SignalInterceptors, interceptor)
        end,
    }
end

function Signal.DisconnectAll<T...>(self: Signal<T...>): ()
    self._SignalListeners = {}
end

function Signal.Destroy<T...>(self: Signal<T...>): ()
    self._SignalListeners = {}
    self._SignalInterceptors = {}
end

return Signal