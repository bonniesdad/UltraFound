-- Build group list and merge in stored member data (from addon messages).
local function BuildGroupData()
  local group = {}
  local playerName = UnitName and UnitName('player') or 'Your Character'
  table.insert(group, playerName)

  local saved = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundNames) or {}
  for _, name in ipairs(saved) do
    table.insert(group, name)
  end

  if #group == 0 then
    table.insert(group, 'Your Character')
  end

  local memberData = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundMemberData) or {}
  local maxLevel = (IsTBC and IsTBC()) and 70 or 60
  local result = {}

  for _, name in ipairs(group) do
    local key = NormalizeName and NormalizeName(name) or name
    local data = memberData[key] or {}
    local profs = data.professions or {}
    if type(profs) ~= 'table' then profs = {} end
    local p1 = profs[1]
    local p2 = profs[2]
    if p1 and type(p1) ~= 'table' then p1 = nil end
    if p2 and type(p2) ~= 'table' then p2 = nil end

    table.insert(result, {
      name = name,
      race = data.race,
      class = data.class,
      level = data.level,
      talentSpec = data.talentSpec,
      professions = { p1, p2 },
      equipment = data.equipment,
    })
  end

  return result, maxLevel
end

local function GetClassBackgroundTexture(className)
  if not className then
    return 'Interface\\AddOns\\UltraFound\\Textures\\bg_warrior.png'
  end

  local key = string.lower(className)

  local map = {
    warrior = 'Interface\\AddOns\\UltraFound\\Textures\\bg_warrior.png',
    mage = 'Interface\\AddOns\\UltraFound\\Textures\\bg_mage.png',
    priest = 'Interface\\AddOns\\UltraFound\\Textures\\bg_priest.png',
    rogue = 'Interface\\AddOns\\UltraFound\\Textures\\bg_rogue.png',
    hunter = 'Interface\\AddOns\\UltraFound\\Textures\\bg_hunter.png',
    warlock = 'Interface\\AddOns\\UltraFound\\Textures\\bg_warlock.png',
    shaman = 'Interface\\AddOns\\UltraFound\\Textures\\bg_shaman.png',
    paladin = 'Interface\\AddOns\\UltraFound\\Textures\\bg_paladin.png',
    druid = 'Interface\\AddOns\\UltraFound\\Textures\\bg_druid.png',
  }

  return map[key] or 'Interface\\AddOns\\UltraFound\\Textures\\bg_warrior.png'
end

local function GetClassColorRGB(className)
  if not className then
    return 1, 1, 1
  end

  local key = string.lower(className)
  local tokenMap = {
    warrior = 'WARRIOR',
    mage = 'MAGE',
    priest = 'PRIEST',
    rogue = 'ROGUE',
    hunter = 'HUNTER',
    warlock = 'WARLOCK',
    shaman = 'SHAMAN',
    paladin = 'PALADIN',
    druid = 'DRUID',
  }

  local token = tokenMap[key]
  if token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
    local c = RAID_CLASS_COLORS[token]
    return c.r, c.g, c.b
  end
  if token and CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[token] then
    local c = CUSTOM_CLASS_COLORS[token]
    return c.r, c.g, c.b
  end

  return 1, 1, 1
end

local ROLE_TEXTURE = {
  TANK = 'Interface\\AddOns\\UltraFound\\Textures\\tank.png',
  HEALER = 'Interface\\AddOns\\UltraFound\\Textures\\healer.png',
  DPS = 'Interface\\AddOns\\UltraFound\\Textures\\dps.png',
}

local function GetStoredRole(characterName)
  if not GLOBAL_SETTINGS or not GLOBAL_SETTINGS.groupFoundRoles or not characterName then
    return nil
  end
  local key = NormalizeName and NormalizeName(characterName) or characterName
  return GLOBAL_SETTINGS.groupFoundRoles[key]
end

local function SetStoredRole(characterName, role)
  if not GLOBAL_SETTINGS or not characterName then return end
  if not GLOBAL_SETTINGS.groupFoundRoles then
    GLOBAL_SETTINGS.groupFoundRoles = {}
  end
  local key = NormalizeName and NormalizeName(characterName) or characterName
  GLOBAL_SETTINGS.groupFoundRoles[key] = role
  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end
end

local function GetStoredOffSpec(characterName)
  if not GLOBAL_SETTINGS or not GLOBAL_SETTINGS.groupFoundOffSpecRoles or not characterName then
    return nil
  end
  local key = NormalizeName and NormalizeName(characterName) or characterName
  return GLOBAL_SETTINGS.groupFoundOffSpecRoles[key]
end

local function SetStoredOffSpec(characterName, role)
  if not GLOBAL_SETTINGS or not characterName then return end
  if not GLOBAL_SETTINGS.groupFoundOffSpecRoles then
    GLOBAL_SETTINGS.groupFoundOffSpecRoles = {}
  end
  local key = NormalizeName and NormalizeName(characterName) or characterName
  GLOBAL_SETTINGS.groupFoundOffSpecRoles[key] = role
  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end
end

local function GetRoleTexture(role)
  if role and ROLE_TEXTURE[role] then
    return ROLE_TEXTURE[role]
  end
  return ROLE_TEXTURE.DPS -- default display until selected
end

-- Sort order for list: Tank, Healer, DPS, then no role
local ROLE_SORT_ORDER = { TANK = 1, HEALER = 2, DPS = 3 }

local function RoleSortOrder(member)
  local role = GetStoredRole(member and member.name)
  return ROLE_SORT_ORDER[role] or 4
end

local function SortGroupDataByRole(groupData)
  table.sort(groupData, function(a, b)
    return RoleSortOrder(a) < RoleSortOrder(b)
  end)
end

-- OSRS-style equipment grid: body 3×5; rings right of chest/belt; boots only in row 5; trinkets below weapon row.
local EQUIP_BODY_LAYOUT = {
  { nil, 'Head', nil },
  { 'Cape', 'Amulet', 'Shoulders' },
  { 'Bracers', 'Chest', 'Ring1' },
  { 'Gloves', 'Belt', 'Ring2' },
  { nil, 'Boots', nil },
}
local EQUIP_WEAPON_SLOTS = { 'MainHand', 'OffHand', 'Wand' }
local EQUIP_TRINKET_SLOTS = { 'Trinket1', 'Trinket2' }

local function CreateEquipmentSlot(parent, slotName, size, backdropOpts)
  local slot = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
  slot:SetSize(size, size)
  slot.slotName = slotName
  slot:SetBackdrop(backdropOpts or {
    bgFile = 'Interface\\Buttons\\WHITE8x8',
    edgeFile = 'Interface\\Buttons\\WHITE8x8',
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  slot:SetBackdropColor(0.12, 0.1, 0.08, 0.95)
  slot:SetBackdropBorderColor(0.45, 0.35, 0.25, 1)
  local icon = slot:CreateTexture(nil, 'ARTWORK')
  icon:SetPoint('TOPLEFT', 1, -1)
  icon:SetPoint('BOTTOMRIGHT', -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  slot.icon = icon
  return slot
end

local function ApplyMemberEquipment(container, equipment)
  if not container or not equipment or type(equipment) ~= 'table' then return end
  for i = 1, container:GetNumChildren() do
    local slot = select(i, container:GetChildren())
    if slot and slot.slotName then
      local itemId = equipment[slot.slotName]
      if itemId and itemId > 0 and GetItemIcon then
        local tex = GetItemIcon(itemId)
        if tex and slot.icon then
          slot.icon:SetTexture(tex)
          slot.icon:Show()
        end
        slot.itemId = itemId
        slot:EnableMouse(true)
        local id = itemId
        slot:SetScript('OnEnter', function()
          if GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(slot, 'ANCHOR_RIGHT')
            GameTooltip:SetHyperlink('item:' .. tostring(id))
          end
        end)
        slot:SetScript('OnLeave', function()
          if GameTooltip then GameTooltip:Hide() end
        end)
      else
        if slot.icon then slot.icon:Hide() slot.icon:SetTexture(nil) end
        slot.itemId = nil
        slot:EnableMouse(false)
        slot:SetScript('OnEnter', nil)
        slot:SetScript('OnLeave', nil)
      end
    end
  end
end

local function CreateEquipmentPanel(parent, anchorTo, anchorPoint, x, y)
  local slotSize = 18
  local gap = 2
  local bodyCols = 3
  local bodyRows = #EQUIP_BODY_LAYOUT
  local bodyW = bodyCols * slotSize + (bodyCols - 1) * gap
  local bodyH = bodyRows * slotSize + (bodyRows - 1) * gap
  local panel = CreateFrame('Frame', nil, parent)
  panel:SetSize(bodyW, bodyH)
  panel:SetPoint(anchorPoint, anchorTo, anchorPoint, x, y)

  -- Body grid (3×5): rings right of chest/belt, trinkets left/right of boots
  for row = 1, bodyRows do
    local layoutRow = EQUIP_BODY_LAYOUT[row]
    for col = 1, bodyCols do
      local name = layoutRow and layoutRow[col]
      if name then
        local slot = CreateEquipmentSlot(panel, name, slotSize)
        local xOffset = (col - 1) * (slotSize + gap)
        local yOffset = -(row - 1) * (slotSize + gap)
        slot:SetPoint('TOPLEFT', panel, 'TOPLEFT', xOffset, yOffset)
      end
    end
  end
  return panel
end

function UltraFound_CreateGroupFoundSummary(parent)
  local content = parent

  local title = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  title:SetPoint('TOP', content, 'TOP', 0, -40)

  local groupData, maxLevel = BuildGroupData()
  SortGroupDataByRole(groupData)

  -- Shared Blizzard dropdown for role selection (context menu: click-away closes, etc.)
  local roleDropdown = _G.UltraFoundRoleDropdown
  if not roleDropdown then
    roleDropdown = CreateFrame('Frame', 'UltraFoundRoleDropdown', UIParent, 'UIDropDownMenuTemplate')
    _G.UltraFoundRoleDropdown = roleDropdown
    UIDropDownMenu_SetWidth(roleDropdown, 120)
    UIDropDownMenu_Initialize(roleDropdown, function(frame, level, menuList)
    if level ~= 1 then return end
    local memberName = frame.memberName
    local roleBtn = frame.roleBtn
    local offSpecBtn = frame.offSpecBtn
    local isOffSpec = frame.isOffSpec
    if not memberName then return end
    if isOffSpec then
      if not offSpecBtn then return end
    else
      if not roleBtn then return end
    end
    local currentRole = isOffSpec and GetStoredOffSpec(memberName) or GetStoredRole(memberName)
    local opts = {
      { text = 'Tank', value = 'TANK' },
      { text = 'Healer', value = 'HEALER' },
      { text = 'DPS', value = 'DPS' },
    }
    for _, opt in ipairs(opts) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt.text
      info.func = function(_, arg1)
        if isOffSpec then
          SetStoredOffSpec(memberName, arg1)
          if offSpecBtn and offSpecBtn.roleIcon then
            offSpecBtn.roleIcon:SetTexture(GetRoleTexture(arg1))
          end
        else
          SetStoredRole(memberName, arg1)
          CloseDropDownMenus()
          local content = roleBtn:GetParent():GetParent()
          if content then
            local children = { content:GetChildren() }
            for i = #children, 1, -1 do
              local child = children[i]
              if child and child.ClearAllPoints then
                child:ClearAllPoints()
                child:SetParent(nil)
                child:Hide()
              end
            end
            UltraFound_CreateGroupFoundSummary(content)
          end
        end
        CloseDropDownMenus()
      end
      info.arg1 = opt.value
      info.checked = (currentRole == opt.value)
      UIDropDownMenu_AddButton(info, level)
    end
  end, 'MENU')
  end

  local previous = title

  for index, member in ipairs(groupData) do
    local frame =
      CreateFrame('Frame', nil, content, 'BackdropTemplate')
    -- Height fits name, level, talent spec, professions, and equipment grid (5 rows of 18px + gaps)
    frame:SetSize(420, 12 + (5 * 18 + 4 * 2) + 12)
    frame:SetPoint('TOP', previous, 'BOTTOM', 0, -10)
    frame:SetBackdrop({
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    -- Class background art
    local bgTex = frame:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetAllPoints(frame)
    bgTex:SetTexture(GetClassBackgroundTexture(member.class))
    bgTex:SetTexCoord(0, 1, 0, 1)
    bgTex:SetAlpha(0.5)

    local leftPadding = 12
    local roleIconSize = 36
    local offSpecIconSize = 24
    local rightIconsWidth = roleIconSize + 4 + offSpecIconSize
    local bodyCols, bodyRows = 3, #EQUIP_BODY_LAYOUT
    local equipSlotSize, equipGap = 18, 2
    local bodyW = bodyCols * equipSlotSize + (bodyCols - 1) * equipGap
    local equipmentPanelWidth = bodyW + 4
    local rightPadding = 12
    local statsColWidth = 175
    -- Divider sits between stats and professions (to the left of role icon)
    local dividerX = leftPadding + statsColWidth + 8
    local profColLeft = dividerX + 10 - 80
    local profColWidth = frame:GetWidth() - profColLeft - rightPadding - equipmentPanelWidth - rightIconsWidth - 8
    local rowSpacing = 18

    -- Name (larger text, left aligned)
    local nameText =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    nameText:SetPoint('TOPLEFT', frame, 'TOPLEFT', leftPadding, -15)
    nameText:SetWidth(statsColWidth)
    nameText:SetJustifyH('LEFT')
    nameText:SetText(member.name or ('Player ' .. index))

    -- Race / Class (larger than before, left aligned)
    local detailsText =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    detailsText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -rowSpacing)
    detailsText:SetWidth(statsColWidth)
    detailsText:SetJustifyH('LEFT')
    detailsText:SetText((member.race or '—') .. ' ' .. (member.class or '—'))
    detailsText:SetTextColor(GetClassColorRGB(member.class))

    -- Level (left aligned)
    local levelText =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    levelText:SetPoint('TOPLEFT', detailsText, 'BOTTOMLEFT', 0, -rowSpacing)
    levelText:SetJustifyH('LEFT')
    levelText:SetText(member.level and ('Level ' .. tostring(member.level) .. ' / ' .. tostring(maxLevel)) or 'Level —')
    levelText:SetTextColor(0.85, 0.85, 0.85)

    local function ProfessionName(prof)
      if not prof or not prof.name or prof.name == '' then
        return 'None selected'
      end
      return prof.name
    end
    local function ProfessionValue(prof)
      if not prof or not prof.level or prof.level == '' then
        return '—'
      end
      return prof.level
    end

    local prof1 = member.professions and member.professions[1]
    local prof2 = member.professions and member.professions[2]

    -- Professions table: aligned with race/class row
    local profHeader =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    profHeader:SetPoint('TOP', detailsText, 'TOP', 0, 0)
    profHeader:SetPoint('LEFT', frame, 'LEFT', profColLeft, 0)
    profHeader:SetText('Professions')
    profHeader:SetTextColor(0.75, 0.75, 0.75)

    local profNameWidth = profColWidth - 52
    local profValueWidth = 50

    -- Profession table: name left, value right (values line up in a column)
    local profColRight = profColLeft + profColWidth - 80
    local prof1Name = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    prof1Name:SetPoint('TOPLEFT', profHeader, 'BOTTOMLEFT', 0, -6)
    prof1Name:SetWidth(profNameWidth)
    prof1Name:SetJustifyH('LEFT')
    prof1Name:SetText(ProfessionName(prof1))
    prof1Name:SetTextColor(0.88, 0.88, 0.88)
    local prof1Value = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    prof1Value:SetPoint('TOPRIGHT', frame, 'TOPLEFT', profColRight, 0)
    prof1Value:SetPoint('TOP', prof1Name, 'TOP', 0, 0)
    prof1Value:SetWidth(profValueWidth)
    prof1Value:SetJustifyH('RIGHT')
    prof1Value:SetText(ProfessionValue(prof1))
    prof1Value:SetTextColor(0.88, 0.88, 0.88)

    local prof2Name = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    prof2Name:SetPoint('TOPLEFT', prof1Name, 'BOTTOMLEFT', 0, -4)
    prof2Name:SetWidth(profNameWidth)
    prof2Name:SetJustifyH('LEFT')
    prof2Name:SetText(ProfessionName(prof2))
    prof2Name:SetTextColor(0.88, 0.88, 0.88)
    local prof2Value = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    prof2Value:SetPoint('TOPRIGHT', frame, 'TOPLEFT', profColRight, 0)
    prof2Value:SetPoint('TOP', prof2Name, 'TOP', 0, 0)
    prof2Value:SetWidth(profValueWidth)
    prof2Value:SetJustifyH('RIGHT')
    prof2Value:SetText(ProfessionValue(prof2))
    prof2Value:SetTextColor(0.88, 0.88, 0.88)

    -- Equipment section (OSRS-style grid, left of role icons)
    local equipPanel = CreateEquipmentPanel(frame, frame, 'TOPRIGHT', -12 - rightIconsWidth - 10, -12)

    -- Off-spec icon (smaller, rightmost; same Tank/Healer/DPS dropdown)
    local offSpecBtn = CreateFrame('Button', nil, frame)
    offSpecBtn:SetSize(24, 24)
    offSpecBtn:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -12, -12)
    offSpecBtn:EnableMouse(true)
    offSpecBtn:SetScript('OnEnter', function(self)
      if GameTooltip and GameTooltip.SetOwner then
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText('Click to set off-spec (Tank / Healer / DPS)', 1, 1, 1)
      end
    end)
    offSpecBtn:SetScript('OnLeave', function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    offSpecBtn:SetScript('OnClick', function(_, btn)
      if btn ~= 'LeftButton' then return end
      roleDropdown.memberName = member.name
      roleDropdown.roleBtn = nil
      roleDropdown.offSpecBtn = offSpecBtn
      roleDropdown.isOffSpec = true
      ToggleDropDownMenu(1, nil, roleDropdown, offSpecBtn, 0, 0)
      local function clearListBackdropBorder()
        local bd = _G.DropdownList1MenuBackdrop
        if bd and bd.SetBackdropBorderColor then
          bd:SetBackdropBorderColor(0, 0, 0, 0)
        end
      end
      if C_Timer and C_Timer.After then
        C_Timer.After(0, clearListBackdropBorder)
      else
        local f = CreateFrame('Frame')
        f:SetScript('OnUpdate', function(self)
          self:SetScript('OnUpdate', nil)
          clearListBackdropBorder()
        end)
      end
    end)
    local offSpecIcon = offSpecBtn:CreateTexture(nil, 'ARTWORK')
    offSpecIcon:SetAllPoints(offSpecBtn)
    offSpecIcon:SetTexture(GetRoleTexture(GetStoredOffSpec(member.name)))
    offSpecIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    offSpecBtn.roleIcon = offSpecIcon

    -- Role icon (main spec, to the left of off-spec)
    local roleBtn = CreateFrame('Button', nil, frame)
    roleBtn:SetSize(36, 36)
    roleBtn:SetPoint('TOPRIGHT', offSpecBtn, 'TOPLEFT', -4, 0)
    roleBtn:EnableMouse(true)
    roleBtn:SetScript('OnEnter', function(self)
      if GameTooltip and GameTooltip.SetOwner then
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText('Click to set role (Tank / Healer / DPS)', 1, 1, 1)
      end
    end)
    roleBtn:SetScript('OnLeave', function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    roleBtn:SetScript('OnClick', function(_, btn)
      if btn ~= 'LeftButton' then return end
      roleDropdown.memberName = member.name
      roleDropdown.roleBtn = roleBtn
      roleDropdown.offSpecBtn = nil
      roleDropdown.isOffSpec = false
      ToggleDropDownMenu(1, nil, roleDropdown, roleBtn, 0, 0)
      local function clearListBackdropBorder()
        local bd = _G.DropdownList1MenuBackdrop
        if bd and bd.SetBackdropBorderColor then
          bd:SetBackdropBorderColor(0, 0, 0, 0)
        end
      end
      if C_Timer and C_Timer.After then
        C_Timer.After(0, clearListBackdropBorder)
      else
        local f = CreateFrame('Frame')
        f:SetScript('OnUpdate', function(self)
          self:SetScript('OnUpdate', nil)
          clearListBackdropBorder()
        end)
      end
    end)

    local roleIcon = roleBtn:CreateTexture(nil, 'ARTWORK')
    roleIcon:SetAllPoints(roleBtn)
    roleIcon:SetTexture(GetRoleTexture(GetStoredRole(member.name)))
    roleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    roleBtn.roleIcon = roleIcon

    -- Weapon row centred below role icons (MainHand, OffHand, Wand)
    local weaponSlotSize, weaponGap = 18, 2
    local weaponRowW = #EQUIP_WEAPON_SLOTS * weaponSlotSize + (#EQUIP_WEAPON_SLOTS - 1) * weaponGap
    local weaponRowFrame = CreateFrame('Frame', nil, frame)
    weaponRowFrame:SetSize(weaponRowW, weaponSlotSize)
    weaponRowFrame:SetPoint('TOP', roleBtn, 'BOTTOM', 10, -12)
    weaponRowFrame:SetPoint('CENTER', roleBtn, 'CENTER', 0, 0)
    for i, name in ipairs(EQUIP_WEAPON_SLOTS) do
      local slot = CreateEquipmentSlot(weaponRowFrame, name, weaponSlotSize)
      slot:SetPoint('TOPLEFT', weaponRowFrame, 'TOPLEFT', (i - 1) * (weaponSlotSize + weaponGap), 0)
    end

    -- Trinket row below weapon row (Trinket1, Trinket2)
    local trinketRowW = #EQUIP_TRINKET_SLOTS * weaponSlotSize + (#EQUIP_TRINKET_SLOTS - 1) * weaponGap
    local trinketRowFrame = CreateFrame('Frame', nil, frame)
    trinketRowFrame:SetSize(trinketRowW, weaponSlotSize)
    trinketRowFrame:SetPoint('TOP', weaponRowFrame, 'BOTTOM', 0, -10)
    trinketRowFrame:SetPoint('CENTER', weaponRowFrame, 'CENTER', 0, 0)
    for i, name in ipairs(EQUIP_TRINKET_SLOTS) do
      local slot = CreateEquipmentSlot(trinketRowFrame, name, weaponSlotSize)
      slot:SetPoint('TOPLEFT', trinketRowFrame, 'TOPLEFT', (i - 1) * (weaponSlotSize + weaponGap), 0)
    end

    -- Show equipment from synced/stored data (item IDs)
    local equip = member.equipment
    if equip then
      ApplyMemberEquipment(equipPanel, equip)
      ApplyMemberEquipment(weaponRowFrame, equip)
      ApplyMemberEquipment(trinketRowFrame, equip)
    end

    previous = frame
  end
end

