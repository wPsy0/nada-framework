--!strict

type SignalCallback<T...> = (T...) -> ()

export type Connection = {
    Disconnect: (self: Connection) -> (),
}

export type Interceptor<T...> = (T...) -> boolean

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable({} :: {
    _Listeners: {SignalCallback<T...>},
    _Interceptors: {Interceptor<T...>},
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

function Signal.new<T...>(interceptors: {Interceptor<T...>}?): Signal<T...>
    return setmetatable({
        _Listeners = {},
        _Interceptors = if interceptors then table.clone(interceptors) else {},
    }, Signal)
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
    for _, interceptor in self._Interceptors do
        if not interceptor(...) then
            return
        end
    end

    for _, listener in self._Listeners do
        task.spawn(listener, ...)
    end
end

function Signal.Connect<T...>(self: Signal<T...>, fn: SignalCallback<T...>): Connection
    self._Listeners = withAdded(self._Listeners, fn)

    local connected = true

    return {
        Disconnect = function(_: Connection): ()
            if not connected then
                return
            end
            connected = false
            self._Listeners = withRemoved(self._Listeners, fn)
        end,
    }
end

function Signal.Once<T...>(self: Signal<T...>, fn: SignalCallback<T...>): Connection
    local connection: Connection
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

function Signal.AddInterceptor<T...>(self: Signal<T...>, interceptor: Interceptor<T...>): Connection
    self._Interceptors = withAdded(self._Interceptors, interceptor)

    local active = true

    return {
        Disconnect = function(_: Connection): ()
            if not active then
                return
            end
            active = false
            self._Interceptors = withRemoved(self._Interceptors, interceptor)
        end,
    }
end

function Signal.DisconnectAll<T...>(self: Signal<T...>): ()
    self._Listeners = {}
end

function Signal.Destroy<T...>(self: Signal<T...>): ()
    self._Listeners = {}
    self._Interceptors = {}
end

return Signal