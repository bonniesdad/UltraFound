local function BuildMockGroupData()
  local group = {}

  local playerName = UnitName and UnitName('player') or 'Your Character'
  table.insert(group, playerName)

  local saved =
    (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundNames) or {}
  for _, name in ipairs(saved) do
    table.insert(group, name)
  end

  if #group == 0 then
    table.insert(group, 'Your Character')
  end

  local races = {
    'Human',
    'Dwarf',
    'Night Elf',
    'Gnome',
    'Orc',
    'Troll',
    'Tauren',
    'Undead',
  }
  local classes = {
    'Warrior',
    'Mage',
    'Priest',
    'Rogue',
    'Hunter',
    'Warlock',
    'Shaman',
    'Paladin',
  }

  local professionPairs = {
    {
      { name = 'Mining', level = '75/300' },
      { name = 'Blacksmithing', level = '60/300' },
    },
    {
      { name = 'Herbalism', level = '90/300' },
      { name = 'Alchemy', level = '80/300' },
    },
    {
      { name = 'Skinning', level = '50/300' },
      { name = 'Leatherworking', level = '40/300' },
    },
    {
      -- Explicit "none selected" example
      { name = nil, level = nil },
      { name = nil, level = nil },
    },
  }

  local maxLevel = (IsTBC and IsTBC()) and 70 or 60

  local result = {}
  for i, name in ipairs(group) do
    local race = races[((i - 1) % #races) + 1]
    local class = classes[((i - 1) % #classes) + 1]
    local pair = professionPairs[((i - 1) % #professionPairs) + 1]
    local level = math.min(10 + (i - 1) * 10, maxLevel)

    table.insert(result, {
      name = name,
      race = race,
      class = class,
      level = level,
      professions = pair,
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

function UltraFound_CreateGroupFoundSummary(parent)
  local content = parent

  local title = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  title:SetPoint('TOP', content, 'TOP', 0, -40)

  local groupData, maxLevel = BuildMockGroupData()

  local previous = title

  for index, member in ipairs(groupData) do
    local frame =
      CreateFrame('Frame', nil, content, 'BackdropTemplate')
    -- Reduce panel height as requested
    frame:SetSize(420, 110)
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

    local nameText =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    nameText:SetPoint('TOP', frame, 'TOP', 0, -8)
    nameText:SetText(member.name or ('Player ' .. index))
    nameText:SetJustifyH('CENTER')

    local detailsText =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    detailsText:SetPoint('TOP', nameText, 'BOTTOM', 0, -4)
    detailsText:SetWidth(360)
    detailsText:SetJustifyH('CENTER')
    detailsText:SetText((member.race or 'Unknown') .. ' ' ..
                          (member.class or 'Adventurer'))
    detailsText:SetTextColor(GetClassColorRGB(member.class))

    -- Level bar + border (bar sits behind the outline)
    local levelBg =
      CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    levelBg:SetSize(346, 16)
    levelBg:SetPoint('TOP', detailsText, 'BOTTOM', 0, -6)
    levelBg:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    levelBg:SetBackdropColor(0, 0, 0, 0.6)
    levelBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    local levelBar =
      CreateFrame('StatusBar', nil, levelBg)
    levelBar:SetStatusBarTexture(
      'Interface\\TARGETINGFRAME\\UI-StatusBar'
    )
    levelBar:SetMinMaxValues(1, maxLevel)
    levelBar:SetValue(member.level or 1)
    levelBar:SetPoint('TOPLEFT', levelBg, 'TOPLEFT', 2, -2)
    levelBar:SetPoint('BOTTOMRIGHT', levelBg, 'BOTTOMRIGHT', -2, 2)
    levelBar:SetStatusBarColor(0.1, 0.7, 0.2)

    local levelText =
      levelBar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    -- Position the level text at the very top of the fill bar,
    -- ensuring it renders above the bar texture.
    levelText:SetPoint('TOP', levelBar, 'TOP', 0, -1)
    levelText:SetJustifyH('CENTER')
    levelText:SetText(
      'Level ' ..
        tostring(member.level or 1) .. ' / ' .. tostring(maxLevel)
    )

    -- Professions header
    local profHeader =
      frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    profHeader:SetPoint('TOP', levelBar, 'BOTTOM', 0, -8)
    profHeader:SetText('Professions')

    -- Left profession bar + text
    local leftProfBg =
      CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    leftProfBg:SetSize(160, 14)
    -- Push further left to use more horizontal space
    leftProfBg:SetPoint('TOPRIGHT', profHeader, 'BOTTOMRIGHT', -40, -6)
    leftProfBg:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    leftProfBg:SetBackdropColor(0, 0, 0, 0.5)
    leftProfBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

    local leftProfBar =
      CreateFrame('StatusBar', nil, leftProfBg)
    leftProfBar:SetStatusBarTexture(
      'Interface\\TARGETINGFRAME\\UI-StatusBar'
    )
    leftProfBar:SetStatusBarColor(0.4, 0.4, 0.4) -- dull grey
    leftProfBar:SetMinMaxValues(0, 300)
    leftProfBar:SetPoint('TOPLEFT', leftProfBg, 'TOPLEFT', 2, -2)
    leftProfBar:SetPoint('BOTTOMRIGHT', leftProfBg, 'BOTTOMRIGHT', -2, 2)

    local leftProf =
      leftProfBar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    leftProf:SetPoint('CENTER', leftProfBar, 'CENTER', 0, 0)
    leftProf:SetWidth(150)
    leftProf:SetJustifyH('CENTER')

    -- Right profession bar + text
    local rightProfBg =
      CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    rightProfBg:SetSize(160, 14)
    -- Push further right to use more horizontal space
    rightProfBg:SetPoint('TOPLEFT', profHeader, 'BOTTOMLEFT', 40, -6)
    rightProfBg:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    rightProfBg:SetBackdropColor(0, 0, 0, 0.5)
    rightProfBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

    local rightProfBar =
      CreateFrame('StatusBar', nil, rightProfBg)
    rightProfBar:SetStatusBarTexture(
      'Interface\\TARGETINGFRAME\\UI-StatusBar'
    )
    rightProfBar:SetStatusBarColor(0.4, 0.4, 0.4) -- dull grey
    rightProfBar:SetMinMaxValues(0, 300)
    rightProfBar:SetPoint('TOPLEFT', rightProfBg, 'TOPLEFT', 2, -2)
    rightProfBar:SetPoint('BOTTOMRIGHT', rightProfBg, 'BOTTOMRIGHT', -2, 2)

    local rightProf =
      rightProfBar:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    rightProf:SetPoint('CENTER', rightProfBar, 'CENTER', 0, 0)
    rightProf:SetWidth(150)
    rightProf:SetJustifyH('CENTER')

    local prof1 = member.professions and member.professions[1]
    local prof2 = member.professions and member.professions[2]

    local function ParseLevelFraction(levelStr)
      if not levelStr or levelStr == '' then
        return 0, 300
      end
      local cur, max = string.match(levelStr, '(%d+)%s*/%s*(%d+)')
      cur = tonumber(cur or '0')
      max = tonumber(max or '300')
      if max <= 0 then max = 300 end
      if cur < 0 then cur = 0 end
      if cur > max then cur = max end
      return cur, max
    end

    local function FormatProfession(prof)
      if not prof or not prof.name or prof.name == '' then
        return 'None selected'
      end
      if prof.level and prof.level ~= '' then
        return prof.name .. ' ' .. prof.level
      end
      return prof.name
    end

    -- Update bars and labels
    local cur1, max1 = ParseLevelFraction(prof1 and prof1.level)
    leftProfBar:SetMinMaxValues(0, max1)
    leftProfBar:SetValue(cur1)
    leftProf:SetText(FormatProfession(prof1))

    local cur2, max2 = ParseLevelFraction(prof2 and prof2.level)
    rightProfBar:SetMinMaxValues(0, max2)
    rightProfBar:SetValue(cur2)
    rightProf:SetText(FormatProfession(prof2))

    previous = frame
  end
end

