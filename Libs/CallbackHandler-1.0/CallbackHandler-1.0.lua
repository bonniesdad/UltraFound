--[[ CallbackHandler-1.0 - same as UltraHardcore ]]
local MAJOR, MINOR = 'CallbackHandler-1.0', 8
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end
local meta = { __index = function(tbl, key) tbl[key] = {}; return tbl[key] end }
local securecallfunction, error = securecallfunction, error
local setmetatable, rawget = setmetatable, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

local function Dispatch(handlers, ...)
  local index, method = next(handlers)
  if not method then return end
  repeat
    securecallfunction(method, ...)
    index, method = next(handlers, index)
  until not method
end

function CallbackHandler.New(_self, target, RegisterName, UnregisterName, UnregisterAllName)
  RegisterName = RegisterName or 'RegisterCallback'
  UnregisterName = UnregisterName or 'UnregisterCallback'
  UnregisterAllName = UnregisterAllName == nil and 'UnregisterAllCallbacks' or UnregisterAllName
  local events = setmetatable({}, meta)
  local registry = { recurse = 0, events = events }

  function registry:Fire(eventname, ...)
    if not rawget(events, eventname) or not next(events[eventname]) then return end
    local oldrecurse = registry.recurse
    registry.recurse = oldrecurse + 1
    Dispatch(events[eventname], eventname, ...)
    registry.recurse = oldrecurse
    if registry.insertQueue and oldrecurse == 0 then
      for event, callbacks in pairs(registry.insertQueue) do
        for object, func in pairs(callbacks) do
          events[event][object] = func
        end
      end
      registry.insertQueue = nil
    end
  end

  target[RegisterName] = function(self, eventname, method, ...)
    if type(eventname) ~= 'string' then error('Usage: eventname - string expected.', 2) end
    method = method or eventname
    if type(method) ~= 'string' and type(method) ~= 'function' then
      error('Usage: methodname - string or function expected.', 2)
    end
    local regfunc
    if type(method) == 'string' then
      if type(self) ~= 'table' or self == target then error('Usage: bad self', 2) end
      if type(self[method]) ~= 'function' then error('method not found on self', 2) end
      regfunc = select('#', ...) >= 1 and function(...) self[method](self, select(1, ...), ...) end or function(...) self[method](self, ...) end
    else
      regfunc = select('#', ...) >= 1 and function(...) method(select(1, ...), ...) end or method
    end
    if events[eventname][self] or registry.recurse < 1 then
      events[eventname][self] = regfunc
    else
      registry.insertQueue = registry.insertQueue or setmetatable({}, meta)
      registry.insertQueue[eventname][self] = regfunc
    end
  end

  target[UnregisterName] = function(self, eventname)
    if not self or self == target then error('bad self', 2) end
    if rawget(events, eventname) and events[eventname][self] then
      events[eventname][self] = nil
    end
    if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
      registry.insertQueue[eventname][self] = nil
    end
  end

  if UnregisterAllName then
    target[UnregisterAllName] = function(...)
      for i = 1, select('#', ...) do
        local s = select(i, ...)
        for eventname, callbacks in pairs(events) do
          if callbacks[s] then callbacks[s] = nil end
        end
      end
    end
  end
  return registry
end
