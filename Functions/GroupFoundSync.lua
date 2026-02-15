-- Group Found sync: send/receive member stats via addon messages.
-- Only accepts data from senders who are in our group found team.

local ADDON_MSG_PREFIX = 'UltraFound'

-- Equipment slot order and WoW inventory slot names (for GetInventorySlotInfo)
local EQUIP_SLOT_ORDER = {
  'Head', 'Cape', 'Amulet', 'Shoulders', 'Bracers', 'Chest', 'Gloves', 'Belt', 'Boots', 'Legs',
  'MainHand', 'OffHand', 'Wand', 'Ring1', 'Ring2', 'Trinket1', 'Trinket2',
}
local EQUIP_TO_WOW_SLOT = {
  Head = 'HeadSlot', Cape = 'BackSlot', Amulet = 'NeckSlot', Shoulders = 'ShoulderSlot',
  Bracers = 'WristSlot', Chest = 'ChestSlot', Gloves = 'HandsSlot', Belt = 'WaistSlot',
  Boots = 'FeetSlot', Legs = 'LegsSlot', MainHand = 'MainHandSlot', OffHand = 'SecondaryHandSlot', Wand = 'RangedSlot',
  Ring1 = 'Finger0Slot', Ring2 = 'Finger1Slot', Trinket1 = 'Trinket0Slot', Trinket2 = 'Trinket1Slot',
}

local function GetPlayerEquipmentForSync()
  local equipment = {}
  if not GetInventorySlotInfo or not GetInventoryItemID then return equipment end
  for _, slotName in ipairs(EQUIP_SLOT_ORDER) do
    local wowSlot = EQUIP_TO_WOW_SLOT[slotName]
    if wowSlot then
      local ok, slotId = pcall(GetInventorySlotInfo, wowSlot)
      if ok and slotId then
        local itemId = GetInventoryItemID('player', slotId)
        if itemId and itemId > 0 then
          equipment[slotName] = itemId
        end
      end
    end
  end
  return equipment
end

local function GetPlayerStatsForSync()
  local race = (UnitRace and UnitRace('player')) or ''
  local className = (UnitClass and UnitClass('player'))
  local class = className or ''
  local level = (UnitLevel and UnitLevel('player')) or 0
  local talentSpec = ''
  local professions = {}

  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
      if not isHeader and skillName and skillName ~= '' and skillMaxRank and skillMaxRank >= 225 then
        local levelStr = (skillRank and skillMaxRank) and (tostring(skillRank) .. '/' .. tostring(skillMaxRank)) or ''
        table.insert(professions, { name = skillName, level = levelStr })
        if #professions >= 2 then break end
      end
    end
  end

  return {
    race = race:gsub('\t', ' '),
    class = class:gsub('\t', ' '),
    level = level,
    talentSpec = talentSpec:gsub('\t', ' '),
    professions = professions,
    equipment = GetPlayerEquipmentForSync(),
  }
end

local function SerializeStats(data)
  local p1 = data.professions and data.professions[1]
  local p2 = data.professions and data.professions[2]
  local equip = data.equipment or {}
  local equipParts = {}
  for _, slotName in ipairs(EQUIP_SLOT_ORDER) do
    table.insert(equipParts, tostring(equip[slotName] or '0'))
  end
  local parts = {
    data.race or '',
    data.class or '',
    tostring(data.level or ''),
    data.talentSpec or '',
    p1 and (p1.name or ''):gsub('\t', ' ') or '',
    p1 and (p1.level or ''):gsub('\t', ' ') or '',
    p2 and (p2.name or ''):gsub('\t', ' ') or '',
    p2 and (p2.level or ''):gsub('\t', ' ') or '',
    table.concat(equipParts, '\t'),
  }
  return table.concat(parts, '\t')
end

local function ParseStatsMessage(msg)
  if not msg or msg == '' then return nil end
  local parts = {}
  for part in (msg .. '\t'):gmatch('([^\t]*)\t') do
    table.insert(parts, part)
  end
  if #parts < 8 then return nil end
  local equipment = {}
  if #parts >= 9 and parts[9] and parts[9] ~= '' then
    local idx = 1
    for idStr in (parts[9] .. '\t'):gmatch('([^\t]*)\t') do
      local slotName = EQUIP_SLOT_ORDER[idx]
      if slotName then
        local id = tonumber(idStr)
        if id and id > 0 then
          equipment[slotName] = id
        end
        idx = idx + 1
      end
    end
  end
  return {
    race = parts[1] ~= '' and parts[1] or nil,
    class = parts[2] ~= '' and parts[2] or nil,
    level = tonumber(parts[3]),
    talentSpec = parts[4] ~= '' and parts[4] or nil,
    professions = {
      (parts[5] ~= '' or parts[6] ~= '') and { name = parts[5], level = parts[6] } or nil,
      (parts[7] ~= '' or parts[8] ~= '') and { name = parts[7], level = parts[8] } or nil,
    },
    equipment = equipment,
  }
end

local function StoreMemberData(normalizedName, data)
  if not GLOBAL_SETTINGS or not normalizedName then return end
  if not GLOBAL_SETTINGS.groupFoundMemberData then
    GLOBAL_SETTINGS.groupFoundMemberData = {}
  end
  local existing = GLOBAL_SETTINGS.groupFoundMemberData[normalizedName]
  if existing and existing.equipment and (not data.equipment or next(data.equipment) == nil) then
    data.equipment = existing.equipment
  end
  GLOBAL_SETTINGS.groupFoundMemberData[normalizedName] = data
  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end
end

-- Guild team sync: send/receive team data for Guild Leaderboards
local function calculatePoints(level, enemiesSlain, dungeonsCompleted, goldGained)
  local levelPts = (tonumber(level) or 0) * 100
  local enemiesPts = math.floor((tonumber(enemiesSlain) or 0) / 10)
  local dungeonsPts = (tonumber(dungeonsCompleted) or 0) * 75
  local goldPts = math.floor((tonumber(goldGained) or 0) / 100000)
  return levelPts + enemiesPts + dungeonsPts + goldPts
end

local function BuildOurTeamForGuildSync()
  local members = {}
  local memberData = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundMemberData) or {}
  local playerName = UnitName and UnitName('player')
  if not playerName then return nil, 0 end

  table.insert(members, {
    name = playerName,
    race = (UnitRace and select(1, UnitRace('player'))) or '—',
    class = (UnitClass and select(1, UnitClass('player'))) or '—',
    level = UnitLevel and UnitLevel('player') or nil,
  })
  for _, name in ipairs(GLOBAL_SETTINGS.groupFoundNames or {}) do
    if name and name ~= '' then
      local key = NormalizeName and NormalizeName(name) or string.lower(name or '')
      local d = memberData[key] or {}
      table.insert(members, {
        name = name,
        race = d.race or '—',
        class = d.class or '—',
        level = d.level,
      })
    end
  end

  local db = _G.UltraStatisticsDB
  local nameToPoints = {}
  if db and db.characterStats and type(db.characterStats) == 'table' then
    local currentGUID = UnitGUID and UnitGUID('player')
    local currentLevel = UnitLevel and UnitLevel('player') or 0
    for guid, stats in pairs(db.characterStats) do
      if stats and type(stats) == 'table' then
        local n = ''
        if GetPlayerInfoByGUID and guid then
          local _, _, _, _, _, nm, _ = GetPlayerInfoByGUID(guid)
          n = nm or ''
        end
        local norm = NormalizeName and NormalizeName(n) or string.lower(n or '')
        if norm and norm ~= '' then
          local lvl = (guid == currentGUID) and currentLevel or nil
          local pts = calculatePoints(lvl or 0, stats.enemiesSlain or 0, stats.dungeonsCompleted or 0, stats.goldGained or 0)
          if not nameToPoints[norm] then nameToPoints[norm] = pts end
        end
      end
    end
  end

  local totalPoints = 0
  for _, m in ipairs(members) do
    local norm = NormalizeName and NormalizeName(m.name) or string.lower(m.name or '')
    local pts = nameToPoints[norm] or 0
    m.points = pts
    totalPoints = totalPoints + pts
  end
  return members, totalPoints
end

local function SerializeGuildTeam(members, totalPoints)
  if not members or #members == 0 then return nil end
  local parts = { 'G', tostring(totalPoints) }
  for _, m in ipairs(members) do
    table.insert(parts, (m.name or ''):gsub('\t', ' '))
    table.insert(parts, tostring(m.level or ''))
    table.insert(parts, (m.race or ''):gsub('\t', ' '))
    table.insert(parts, (m.class or ''):gsub('\t', ' '))
    table.insert(parts, tostring(m.points or 0))
  end
  return table.concat(parts, '\t')
end

local function ParseGuildTeamMessage(msg)
  if not msg or msg == '' then return nil end
  local parts = {}
  for part in (msg .. '\t'):gmatch('([^\t]*)\t') do
    table.insert(parts, part)
  end
  if #parts < 2 or parts[1] ~= 'G' then return nil end
  local totalPoints = tonumber(parts[2]) or 0
  local members = {}
  -- New format: 5 fields per member (name, level, race, class, points). Old: 4 fields.
  local stride = (#parts >= 7 and tonumber(parts[7])) and 5 or 4
  for i = 3, #parts - stride + 1, stride do
    if parts[i] and parts[i] ~= '' then
      local m = {
        name = parts[i],
        level = tonumber(parts[i + 1]) or nil,
        race = parts[i + 2] and parts[i + 2] ~= '' and parts[i + 2] or '—',
        class = parts[i + 3] and parts[i + 3] ~= '' and parts[i + 3] or '—',
      }
      if stride == 5 and parts[i + 4] then
        m.points = tonumber(parts[i + 4]) or 0
      end
      table.insert(members, m)
    end
  end
  if #members == 0 then return nil end
  return { members = members, totalPoints = totalPoints }
end

local function StoreGuildTeamData(sender, teamData)
  if not GLOBAL_SETTINGS or not sender or not teamData then return end
  if not GLOBAL_SETTINGS.guildTeamsData then
    GLOBAL_SETTINGS.guildTeamsData = {}
  end
  local key = NormalizeName and NormalizeName(sender) or string.lower(sender or '')
  GLOBAL_SETTINGS.guildTeamsData[key] = {
    senderName = sender,
    members = teamData.members,
    totalPoints = teamData.totalPoints,
  }
  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end
end

local function SendGuildTeamStats()
  if not GLOBAL_SETTINGS then return end
  if not (GLOBAL_SETTINGS.groupSelfFound or GLOBAL_SETTINGS.guildSelfFound) then return end
  -- Classic: GetGuildInfo("player") returns guild name if in guild, nil otherwise
  if not (GetGuildInfo and GetGuildInfo('player')) then return end
  if not SendAddonMessage then return end

  local members, totalPoints = BuildOurTeamForGuildSync()
  if not members or #members == 0 then return end

  local msg = SerializeGuildTeam(members, totalPoints)
  if msg and #msg < 255 then
    SendAddonMessage(ADDON_MSG_PREFIX, msg, 'GUILD')
  end
end

local function SendMyStats()
  if not GLOBAL_SETTINGS or not GLOBAL_SETTINGS.groupSelfFound then return end
  if GetNumGroupMembers and GetNumGroupMembers() < 1 then return end
  local myName = UnitName and UnitName('player')
  if not myName then return end
  local data = GetPlayerStatsForSync()
  StoreMemberData(NormalizeName(myName), data)
  local msg = SerializeStats(data)
  if msg and SendAddonMessage then
    if #msg >= 255 then
      data.equipment = {}
      msg = SerializeStats(data)
    end
    if msg and #msg < 255 then
      SendAddonMessage(ADDON_MSG_PREFIX, msg, 'PARTY')
    end
  end
end

local frame = CreateFrame('Frame')
frame:RegisterEvent('GROUP_ROSTER_UPDATE')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:RegisterEvent('GUILD_ROSTER_UPDATE')
frame:RegisterEvent('CHAT_MSG_ADDON')

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)
end

frame:SetScript('OnEvent', function(self, event, ...)
  if event == 'GROUP_ROSTER_UPDATE' or event == 'PLAYER_ENTERING_WORLD' or event == 'GUILD_ROSTER_UPDATE' then
    if event == 'PLAYER_ENTERING_WORLD' then
      frame:SetScript('OnUpdate', function(f)
        f:SetScript('OnUpdate', nil)
        SendMyStats()
        SendGuildTeamStats()
      end)
    else
      SendMyStats()
      SendGuildTeamStats()
    end
    return
  end

  if event == 'CHAT_MSG_ADDON' then
    local prefix, msg, channel, sender = ...
    if prefix ~= ADDON_MSG_PREFIX or not sender or sender == '' then return end

    if channel == 'PARTY' then
      if not GLOBAL_SETTINGS or not GLOBAL_SETTINGS.groupSelfFound then return end
      if not IsAllowedByGroupList then return end
      if not IsAllowedByGroupList(sender) then return end
      local data = ParseStatsMessage(msg)
      if data then
        StoreMemberData(NormalizeName(sender), data)
      end
    elseif channel == 'GUILD' then
      local teamData = ParseGuildTeamMessage(msg)
      if teamData then
        StoreGuildTeamData(sender, teamData)
      end
    end
  end
end)

-- Expose for UI refresh after receiving data (e.g. GroupFoundSummary can call this)
function UltraFound_RequestGroupSync()
  SendMyStats()
  SendGuildTeamStats()
end
