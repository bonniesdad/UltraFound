-- LibDBIcon-1.0 - bundled for Ultra Found (same as UltraHardcore)
local DBICON10 = 'LibDBIcon-1.0'
local DBICON10_MINOR = 55
if not LibStub then error(DBICON10 .. ' requires LibStub.') end
local ldb = LibStub('LibDataBroker-1.1', true)
if not ldb then error(DBICON10 .. ' requires LibDataBroker-1.1.') end
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub('CallbackHandler-1.0'):New(lib)
lib.radius = lib.radius or 5
local next, Minimap, CreateFrame, AddonCompartmentFrame = next, Minimap, CreateFrame, AddonCompartmentFrame
lib.tooltip = lib.tooltip or CreateFrame('GameTooltip', 'LibDBIconTooltip', UIParent, 'GameTooltipTemplate')
local isDraggingButton = false

function lib:IconCallback(event, name, key, value)
  if lib.objects[name] then
    if key == 'icon' then
      lib.objects[name].icon:SetTexture(value)
      if lib:IsButtonInCompartment(name) and lib:IsButtonCompartmentAvailable() then
        local addonList = AddonCompartmentFrame.registeredAddons
        for i = 1, #addonList do
          if addonList[i].text == name then addonList[i].icon = value; return end
        end
      end
    elseif key == 'iconCoords' then lib.objects[name].icon:UpdateCoord()
    elseif key == 'iconR' then local _, g, b = lib.objects[name].icon:GetVertexColor(); lib.objects[name].icon:SetVertexColor(value, g, b)
    elseif key == 'iconG' then local r, _, b = lib.objects[name].icon:GetVertexColor(); lib.objects[name].icon:SetVertexColor(r, value, b)
    elseif key == 'iconB' then local r, g = lib.objects[name].icon:GetVertexColor(); lib.objects[name].icon:SetVertexColor(r, g, value)
    end
  end
end
if not lib.callbackRegistered then
  ldb.RegisterCallback(lib, 'LibDataBroker_AttributeChanged__icon', 'IconCallback')
  ldb.RegisterCallback(lib, 'LibDataBroker_AttributeChanged__iconCoords', 'IconCallback')
  ldb.RegisterCallback(lib, 'LibDataBroker_AttributeChanged__iconR', 'IconCallback')
  ldb.RegisterCallback(lib, 'LibDataBroker_AttributeChanged__iconG', 'IconCallback')
  ldb.RegisterCallback(lib, 'LibDataBroker_AttributeChanged__iconB', 'IconCallback')
  lib.callbackRegistered = true
end

local function getAnchors(frame)
  local x, y = frame:GetCenter()
  if not x or not y then return 'CENTER' end
  local hhalf = (x > UIParent:GetWidth() * 2 / 3) and 'RIGHT' or (x < UIParent:GetWidth() / 3) and 'LEFT' or ''
  local vhalf = (y > UIParent:GetHeight() / 2) and 'TOP' or 'BOTTOM'
  return vhalf .. hhalf, frame, (vhalf == 'TOP' and 'BOTTOM' or 'TOP') .. hhalf
end

local function onEnter(self)
  if isDraggingButton then return end
  for _, button in next, lib.objects do
    if button.showOnMouseover then button.fadeOut:Stop(); button:SetAlpha(1) end
  end
  local obj = self.dataObject
  if obj.OnTooltipShow then lib.tooltip:SetOwner(self, 'ANCHOR_NONE'); lib.tooltip:SetPoint(getAnchors(self)); obj.OnTooltipShow(lib.tooltip); lib.tooltip:Show()
  elseif obj.OnEnter then obj.OnEnter(self) end
end

local function onLeave(self)
  lib.tooltip:Hide()
  if not isDraggingButton then
    for _, button in next, lib.objects do if button.showOnMouseover then button.fadeOut:Play() end end
  end
  local obj = self.dataObject
  if obj.OnLeave then obj.OnLeave(self) end
end

local function onEnterCompartment(self, menu)
  local object = lib.objects[menu.text]
  if object and object.dataObject then
    if object.dataObject.OnTooltipShow then lib.tooltip:SetOwner(self, 'ANCHOR_NONE'); lib.tooltip:SetPoint(getAnchors(self)); object.dataObject.OnTooltipShow(lib.tooltip); lib.tooltip:Show()
    elseif object.dataObject.OnEnter then object.dataObject.OnEnter(self) end
  end
end

local function onLeaveCompartment(self, menu)
  lib.tooltip:Hide()
  local object = lib.objects[menu.text]
  if object and object.dataObject and object.dataObject.OnLeave then object.dataObject.OnLeave(self) end
end

local onDragStart, updatePosition
do
  local minimapShapes = { ROUND = { true, true, true, true }, SQUARE = { false, false, false, false }, ['CORNER-TOPLEFT'] = { false, false, false, true }, ['CORNER-TOPRIGHT'] = { false, false, true, false }, ['CORNER-BOTTOMLEFT'] = { false, true, false, false }, ['CORNER-BOTTOMRIGHT'] = { true, false, false, false }, ['SIDE-LEFT'] = { false, true, false, true }, ['SIDE-RIGHT'] = { true, false, true, false }, ['SIDE-TOP'] = { false, false, true, true }, ['SIDE-BOTTOM'] = { true, true, false, false }, ['TRICORNER-TOPLEFT'] = { false, true, true, true }, ['TRICORNER-TOPRIGHT'] = { true, false, true, true }, ['TRICORNER-BOTTOMLEFT'] = { true, true, false, true }, ['TRICORNER-BOTTOMRIGHT'] = { true, true, true, false } }
  local rad, cos, sin, sqrt, max, min = math.rad, math.cos, math.sin, math.sqrt, math.max, math.min
  function updatePosition(button, position)
    local angle = rad(position or 225)
    local x, y, q = cos(angle), sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local minimapShape = GetMinimapShape and GetMinimapShape() or 'ROUND'
    local quadTable = minimapShapes[minimapShape]
    local w, h = (Minimap:GetWidth() / 2) + lib.radius, (Minimap:GetHeight() / 2) + lib.radius
    if quadTable[q] then x, y = x * w, y * h
    else x = max(-w, min(x * (sqrt(2 * w ^ 2) - 10), w)); y = max(-h, min(y * (sqrt(2 * h ^ 2) - 10), h)) end
    button:SetPoint('CENTER', Minimap, 'CENTER', x, y)
  end
end

local function onClick(self, b) if self.dataObject.OnClick then self.dataObject.OnClick(self, b) end end
local function onMouseDown(self) self.isMouseDown = true; self.icon:UpdateCoord() end
local function onMouseUp(self) self.isMouseDown = false; self.icon:UpdateCoord() end

do
  local deg, atan2 = math.deg, math.atan2
  local function onUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local pos = self.db and (deg(atan2(py - my, px - mx)) % 360) or 225
    if self.db then self.db.minimapPos = pos else self.minimapPos = pos end
    updatePosition(self, pos)
  end
  function onDragStart(self)
    self:LockHighlight(); self.isMouseDown = true; self.icon:UpdateCoord(); self:SetScript('OnUpdate', onUpdate)
    isDraggingButton = true; lib.tooltip:Hide()
    for _, button in next, lib.objects do if button.showOnMouseover then button.fadeOut:Stop(); button:SetAlpha(1) end end
  end
end

local function onDragStop(self)
  self:SetScript('OnUpdate', nil); self.isMouseDown = false; self.icon:UpdateCoord(); self:UnlockHighlight()
  isDraggingButton = false
  for _, button in next, lib.objects do if button.showOnMouseover then button.fadeOut:Play() end end
end

local defaultCoords = { 0, 1, 0, 1 }
local function updateCoord(self)
  local coords = self:GetParent().dataObject.iconCoords or defaultCoords
  local dx, dy = 0, 0
  if not self:GetParent().isMouseDown then dx = (coords[2] - coords[1]) * 0.05; dy = (coords[4] - coords[3]) * 0.05 end
  self:SetTexCoord(coords[1] + dx, coords[2] - dx, coords[3] + dy, coords[4] - dy)
end

local function createButton(name, object, db, customCompartmentIcon)
  local button = CreateFrame('Button', 'LibDBIcon10_' .. name, Minimap)
  button.dataObject = object; button.db = db
  button:SetFrameStrata('MEDIUM'); button:SetFixedFrameStrata(true); button:SetFrameLevel(8); button:SetFixedFrameLevel(true)
  button:SetSize(31, 31); button:RegisterForClicks('anyUp'); button:RegisterForDrag('LeftButton')
  button:SetHighlightTexture(136477)
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    local overlay = button:CreateTexture(nil, 'OVERLAY'); overlay:SetSize(50, 50); overlay:SetTexture(136430); overlay:SetPoint('TOPLEFT', button, 'TOPLEFT')
    local bg = button:CreateTexture(nil, 'BACKGROUND'); bg:SetSize(24, 24); bg:SetTexture(136467); bg:SetPoint('CENTER', button, 'CENTER')
    local icon = button:CreateTexture(nil, 'ARTWORK'); icon:SetSize(18, 18); icon:SetTexture(object.icon); icon:SetPoint('CENTER', button, 'CENTER'); button.icon = icon
  else
    local overlay = button:CreateTexture(nil, 'OVERLAY'); overlay:SetSize(53, 53); overlay:SetTexture(136430); overlay:SetPoint('TOPLEFT')
    local bg = button:CreateTexture(nil, 'BACKGROUND'); bg:SetSize(20, 20); bg:SetTexture(136467); bg:SetPoint('TOPLEFT', 7, -5)
    local icon = button:CreateTexture(nil, 'ARTWORK'); icon:SetSize(17, 17); icon:SetTexture(object.icon); icon:SetPoint('TOPLEFT', 7, -6); button.icon = icon
  end
  button.isMouseDown = false
  local r, g, b = button.icon:GetVertexColor()
  button.icon:SetVertexColor(object.iconR or r, object.iconG or g, object.iconB or b)
  button.icon.UpdateCoord = updateCoord; button.icon:UpdateCoord()
  button:SetScript('OnEnter', onEnter); button:SetScript('OnLeave', onLeave); button:SetScript('OnClick', onClick)
  if not db or not db.lock then button:SetScript('OnDragStart', onDragStart); button:SetScript('OnDragStop', onDragStop) end
  button:SetScript('OnMouseDown', onMouseDown); button:SetScript('OnMouseUp', onMouseUp)
  button.fadeOut = button:CreateAnimationGroup()
  local animOut = button.fadeOut:CreateAnimation('Alpha'); animOut:SetOrder(1); animOut:SetDuration(0.2); animOut:SetFromAlpha(1); animOut:SetToAlpha(0); animOut:SetStartDelay(1); button.fadeOut:SetToFinalAlpha(true)
  lib.objects[name] = button
  if lib.loggedIn then updatePosition(button, db and db.minimapPos); if not db or not db.hide then button:Show() else button:Hide() end end
  if db and db.showInCompartment then lib:AddButtonToCompartment(name, customCompartmentIcon) end
  lib.callbacks:Fire('LibDBIcon_IconCreated', button, name)
end

if not lib.loggedIn then
  local frame = CreateFrame('Frame')
  frame:SetScript('OnEvent', function(self)
    for _, button in next, lib.objects do updatePosition(button, button.db and button.db.minimapPos); if not button.db or not button.db.hide then button:Show() else button:Hide() end end
    lib.loggedIn = true; self:SetScript('OnEvent', nil)
  end)
  frame:RegisterEvent('PLAYER_LOGIN')
end

do
  local function OnMinimapEnter()
    if isDraggingButton then return end
    for _, button in next, lib.objects do if button.showOnMouseover then button.fadeOut:Stop(); button:SetAlpha(1) end end
  end
  local function OnMinimapLeave()
    if isDraggingButton then return end
    for _, button in next, lib.objects do if button.showOnMouseover then button.fadeOut:Play() end end
  end
  Minimap:HookScript('OnEnter', OnMinimapEnter); Minimap:HookScript('OnLeave', OnMinimapLeave)
end

function lib:Register(name, object, db, customCompartmentIcon)
  if not object.icon then error("Can't register LDB objects without icons set!") end
  if lib:GetMinimapButton(name) then error(DBICON10 .. ": Object '" .. name .. "' is already registered.") end
  createButton(name, object, db, customCompartmentIcon)
end
function lib:Lock(name) local b = lib:GetMinimapButton(name); if b then b:SetScript('OnDragStart', nil); b:SetScript('OnDragStop', nil); if b.db then b.db.lock = true end end end
function lib:Unlock(name) local b = lib:GetMinimapButton(name); if b then b:SetScript('OnDragStart', onDragStart); b:SetScript('OnDragStop', onDragStop); if b.db then b.db.lock = nil end end end
function lib:Hide(name) local b = lib:GetMinimapButton(name); if b then b:Hide() end end
function lib:Show(name) local b = lib:GetMinimapButton(name); if b then b:Show(); updatePosition(b, b.db and b.db.minimapPos or b.minimapPos) end end
function lib:IsRegistered(name) return lib.objects[name] and true or false end
function lib:Refresh(name, db) local b = lib:GetMinimapButton(name); if b then if db then b.db = db end; updatePosition(b, b.db and b.db.minimapPos or b.minimapPos); if not b.db or not b.db.hide then b:Show() else b:Hide() end; if not b.db or not b.db.lock then b:SetScript('OnDragStart', onDragStart); b:SetScript('OnDragStop', onDragStop) else b:SetScript('OnDragStart', nil); b:SetScript('OnDragStop', nil) end end end
function lib:ShowOnEnter(name, value) local b = lib:GetMinimapButton(name); if b then if value then b.showOnMouseover = true; b.fadeOut:Stop(); b:SetAlpha(0) else b.showOnMouseover = false; b.fadeOut:Stop(); b:SetAlpha(1) end end end
function lib:GetMinimapButton(name) return lib.objects[name] end
function lib:GetButtonList() local t = {}; for name in next, lib.objects do t[#t + 1] = name end; return t end
function lib:SetButtonRadius(radius) if type(radius) == 'number' then lib.radius = radius; for _, button in next, lib.objects do updatePosition(button, button.db and button.db.minimapPos or button.minimapPos) end end end
function lib:SetButtonToPosition(button, position) updatePosition(lib.objects[button] or button, position) end
function lib:IsButtonCompartmentAvailable() return AddonCompartmentFrame and true end
function lib:IsButtonInCompartment(buttonName) local o = lib.objects[buttonName]; return o and o.db and o.db.showInCompartment end
function lib:AddButtonToCompartment(buttonName, customIcon)
  if lib:IsButtonCompartmentAvailable() then
    local object = lib.objects[buttonName]
    if object and not object.compartmentData then
      if object.db then object.db.showInCompartment = true end
      object.compartmentData = { text = buttonName, icon = customIcon or object.dataObject.icon, notCheckable = true, registerForAnyClick = true, func = function(_, menuInputData, menu) object.dataObject.OnClick(menu, menuInputData.buttonName) end, funcOnEnter = onEnterCompartment, funcOnLeave = onLeaveCompartment }
      AddonCompartmentFrame:RegisterAddon(object.compartmentData)
    end
  end
end
function lib:RemoveButtonFromCompartment(buttonName)
  if lib:IsButtonCompartmentAvailable() then
    local object = lib.objects[buttonName]
    if object and object.compartmentData then
      for i = 1, #AddonCompartmentFrame.registeredAddons do
        if AddonCompartmentFrame.registeredAddons[i] == object.compartmentData then
          object.compartmentData = nil; if object.db then object.db.showInCompartment = nil end
          table.remove(AddonCompartmentFrame.registeredAddons, i); AddonCompartmentFrame:UpdateDisplay(); return
        end
      end
    end
  end
end

for name, button in next, lib.objects do
  if not button.db or not button.db.lock then button:SetScript('OnDragStart', onDragStart); button:SetScript('OnDragStop', onDragStop) end
  button:SetScript('OnEnter', onEnter); button:SetScript('OnLeave', onLeave); button:SetScript('OnClick', onClick); button:SetScript('OnMouseDown', onMouseDown); button:SetScript('OnMouseUp', onMouseUp)
  if not button.fadeOut then button.fadeOut = button:CreateAnimationGroup(); local a = button.fadeOut:CreateAnimation('Alpha'); a:SetOrder(1); a:SetDuration(0.2); a:SetFromAlpha(1); a:SetToAlpha(0); a:SetStartDelay(1); button.fadeOut:SetToFinalAlpha(true) end
end
lib:SetButtonRadius(lib.radius)
if lib.notCreated then for name in next, lib.notCreated do createButton(name, lib.notCreated[name][1], lib.notCreated[name][2]) end; lib.notCreated = nil end
