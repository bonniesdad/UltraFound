assert(LibStub, 'LibDataBroker-1.1 requires LibStub')
assert(LibStub:GetLibrary('CallbackHandler-1.0', true), 'LibDataBroker-1.1 requires CallbackHandler-1.0')
local lib, oldminor = LibStub:NewLibrary('LibDataBroker-1.1', 4)
if not lib then return end
oldminor = oldminor or 0
lib.callbacks = lib.callbacks or LibStub:GetLibrary('CallbackHandler-1.0'):New(lib)
lib.attributestorage, lib.namestorage, lib.proxystorage = lib.attributestorage or {}, lib.namestorage or {}, lib.proxystorage or {}
local attributestorage, namestorage, callbacks = lib.attributestorage, lib.namestorage, lib.callbacks
if oldminor < 2 then
  lib.domt = { __metatable = 'access denied', __index = function(self, key) return attributestorage[self] and attributestorage[self][key] end }
end
if oldminor < 3 then
  lib.domt.__newindex = function(self, key, value)
    if not attributestorage[self] then attributestorage[self] = {} end
    if attributestorage[self][key] == value then return end
    attributestorage[self][key] = value
    local name = namestorage[self]
    if name then
      callbacks:Fire('LibDataBroker_AttributeChanged', name, key, value, self)
      callbacks:Fire('LibDataBroker_AttributeChanged_' .. name, name, key, value, self)
      callbacks:Fire('LibDataBroker_AttributeChanged_' .. name .. '_' .. key, name, key, value, self)
      callbacks:Fire('LibDataBroker_AttributeChanged__' .. key, name, key, value, self)
    end
  end
end
if oldminor < 2 then
  function lib:NewDataObject(name, dataobj)
    if self.proxystorage[name] then return end
    if dataobj then
      assert(type(dataobj) == 'table', 'Invalid dataobj')
      self.attributestorage[dataobj] = {}
      for i, v in pairs(dataobj) do self.attributestorage[dataobj][i] = v; dataobj[i] = nil end
    end
    dataobj = setmetatable(dataobj or {}, self.domt)
    self.proxystorage[name], self.namestorage[dataobj] = dataobj, name
    self.callbacks:Fire('LibDataBroker_DataObjectCreated', name, dataobj)
    return dataobj
  end
end
if oldminor < 1 then
  function lib:DataObjectIterator() return pairs(self.proxystorage) end
  function lib:GetDataObjectByName(dataobjectname) return self.proxystorage[dataobjectname] end
  function lib:GetNameByDataObject(dataobject) return self.namestorage[dataobject] end
end
if oldminor < 4 then
  function lib:pairs(dataobject_or_name)
    local dataobj = self.proxystorage[dataobject_or_name] or dataobject_or_name
    assert(attributestorage[dataobj], 'Data object not found')
    return pairs(attributestorage[dataobj])
  end
  function lib:ipairs(dataobject_or_name)
    local dataobj = self.proxystorage[dataobject_or_name] or dataobject_or_name
    assert(attributestorage[dataobj], 'Data object not found')
    return ipairs(attributestorage[dataobj])
  end
end
