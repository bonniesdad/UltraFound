-- Group Found sync: send/receive member stats via addon messages.
-- Only accepts data from senders who are in our group found team.

local ADDON_MSG_PREFIX = 'UltraFound'

local function SyncLog(what, ...)
  local msg = '|cff69b4ff[UF Sync]|r ' .. what
  if select('#', ...) > 0 then
    msg = msg .. ': ' .. string.format(...)
  end
  -- print(msg)
end

-- Use C_ChatInfo.SendAddonMessage (Classic Era) when global SendAddonMessage is not available
local function DoSendAddonMessage(prefix, message, channel)
  if SendAddonMessage then
    SendAddonMessage(prefix, message, channel)
    return true
  end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(prefix, message, channel)
    return true
  end
  return false
end

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

  -- Only include skills from the Professions accordion (Character -> Skills -> Professions)
  -- Track section by header: collect only skills under "Professions"
  -- Excludes: talent trees (Class Skills), languages (Languages), weapon skills, secondary (First Aid etc)
  local PROFESSION_HEADERS = {
    ['Professions'] = true,
  }
  if _G.PROFESSIONS_PROFESSION then
    PROFESSION_HEADERS[tostring(_G.PROFESSIONS_PROFESSION)] = true
  end
  if GetNumSkillLines and GetSkillLineInfo then
    local inProfessionSection = false
    for i = 1, GetNumSkillLines() do
      local skillName, header, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
      local isHeader = (header == 1 or header == true)
      if isHeader then
        inProfessionSection = skillName and PROFESSION_HEADERS[skillName]
      elseif inProfessionSection and skillName and skillName ~= '' and skillMaxRank and skillRank ~= nil then
        local levelStr = tostring(skillRank) .. '/' .. tostring(skillMaxRank)
        table.insert(professions, { name = skillName, level = levelStr })
        if #professions >= 2 then break end
      end
    end
  end

  -- Leaderboard stats from UltraStatistics
  local enemiesSlain, dungeonsCompleted, goldGained, highestCritValue, healthPotionsUsed = 0, 0, 0, 0, 0
  local db = _G.UltraStatisticsDB
  if db and db.characterStats and type(db.characterStats) == 'table' then
    local guid = UnitGUID and UnitGUID('player')
    if guid and db.characterStats[guid] then
      local s = db.characterStats[guid]
      enemiesSlain = s.enemiesSlain or 0
      dungeonsCompleted = s.dungeonsCompleted or 0
      goldGained = s.goldGained or 0
      highestCritValue = s.highestCritValue or 0
      healthPotionsUsed = s.healthPotionsUsed or 0
    end
  end

  return {
    race = race:gsub('\t', ' '),
    class = class:gsub('\t', ' '),
    level = level,
    talentSpec = talentSpec:gsub('\t', ' '),
    professions = professions,
    equipment = GetPlayerEquipmentForSync(),
    enemiesSlain = enemiesSlain,
    dungeonsCompleted = dungeonsCompleted,
    goldGained = goldGained,
    highestCritValue = highestCritValue,
    healthPotionsUsed = healthPotionsUsed,
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
    'S',  -- format marker: S = stats follow
    tostring(data.enemiesSlain or 0),
    tostring(data.dungeonsCompleted or 0),
    tostring(data.goldGained or 0),
    tostring(data.highestCritValue or 0),
    tostring(data.healthPotionsUsed or 0),
    table.concat(equipParts, '\t'),
  }
  return table.concat(parts, '\t')
end

local BASE_PARTS = 8   -- race, class, level, talentSpec, p1name, p1level, p2name, p2level
local EQUIP_START_OLD = 9
local EQUIP_START_NEW = 15  -- after format 'S' + 5 stats

local function ParseStatsMessage(msg)
  if not msg or msg == '' then return nil end
  local parts = {}
  for part in (msg .. '\t'):gmatch('([^\t]*)\t') do
    table.insert(parts, part)
  end
  if #parts < BASE_PARTS then return nil end

  local hasStats = (parts[9] == 'S') and (#parts >= 14)
  local equipStart = hasStats and EQUIP_START_NEW or EQUIP_START_OLD
  local equipment = {}
  for idx = 1, #EQUIP_SLOT_ORDER do
    local partIdx = equipStart - 1 + idx
    if partIdx <= #parts and parts[partIdx] then
      local slotName = EQUIP_SLOT_ORDER[idx]
      if slotName then
        local id = tonumber(parts[partIdx])
        if id and id > 0 then
          equipment[slotName] = id
        end
      end
    end
  end

  local enemiesSlain, dungeonsCompleted, goldGained, highestCritValue, healthPotionsUsed
  if hasStats then
    enemiesSlain = tonumber(parts[10]) or 0
    dungeonsCompleted = tonumber(parts[11]) or 0
    goldGained = tonumber(parts[12]) or 0
    highestCritValue = tonumber(parts[13]) or 0
    healthPotionsUsed = tonumber(parts[14]) or 0
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
    enemiesSlain = enemiesSlain,
    dungeonsCompleted = dungeonsCompleted,
    goldGained = goldGained,
    highestCritValue = highestCritValue,
    healthPotionsUsed = healthPotionsUsed,
  }
end

local function StoreMemberData(normalizedName, data)
  if not GLOBAL_SETTINGS or not normalizedName then
    SyncLog('StoreMemberData skipped', 'missing GLOBAL_SETTINGS or normalizedName')
    return
  end
  if not GLOBAL_SETTINGS.groupFoundMemberData then
    GLOBAL_SETTINGS.groupFoundMemberData = {}
  end
  local existing = GLOBAL_SETTINGS.groupFoundMemberData[normalizedName]
  if existing and existing.equipment and (not data.equipment or next(data.equipment) == nil) then
    data.equipment = existing.equipment
  end
  GLOBAL_SETTINGS.groupFoundMemberData[normalizedName] = data
  SyncLog('StoreMemberData stored', '%s L%d %s', normalizedName, data.level or 0, data.class or '?')
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
    -- NOTE: gsub returns (string, nReplacements). Wrap in extra parens to pass only the string.
    table.insert(parts, ((m.name or ''):gsub('\t', ' ')))
    table.insert(parts, tostring(m.level or ''))
    table.insert(parts, ((m.race or ''):gsub('\t', ' ')))
    table.insert(parts, ((m.class or ''):gsub('\t', ' ')))
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
  if not GLOBAL_SETTINGS or not sender or not teamData then
    SyncLog('StoreGuildTeamData skipped', 'missing GLOBAL_SETTINGS, sender or teamData')
    return
  end
  if not GLOBAL_SETTINGS.guildTeamsData then
    GLOBAL_SETTINGS.guildTeamsData = {}
  end
  local key = NormalizeName and NormalizeName(sender) or string.lower(sender or '')
  GLOBAL_SETTINGS.guildTeamsData[key] = {
    senderName = sender,
    members = teamData.members,
    totalPoints = teamData.totalPoints,
  }
  SyncLog('StoreGuildTeamData stored', '%s: %d members, %d pts', sender, #teamData.members, teamData.totalPoints)
  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end
end

local function SendGuildTeamStats()
  SyncLog('SendGuildTeamStats called')
  if not GLOBAL_SETTINGS then
    SyncLog('SendGuildTeamStats early exit', 'no GLOBAL_SETTINGS')
    return
  end
  -- Classic: GetGuildInfo("player") returns guild name if in guild, nil otherwise
  if not (GetGuildInfo and GetGuildInfo('player')) then
    SyncLog('SendGuildTeamStats early exit', 'not in guild')
    return
  end
  if not (SendAddonMessage or (C_ChatInfo and C_ChatInfo.SendAddonMessage)) then
    SyncLog('SendGuildTeamStats early exit', 'SendAddonMessage / C_ChatInfo.SendAddonMessage not available')
    return
  end

  local members, totalPoints = BuildOurTeamForGuildSync()
  if not members or #members == 0 then
    SyncLog('SendGuildTeamStats early exit', 'no members to send (members=%s)', tostring(members and #members))
    return
  end

  local msg = SerializeGuildTeam(members, totalPoints)
  if not msg then
    SyncLog('SendGuildTeamStats early exit', 'SerializeGuildTeam returned nil')
    return
  end
  if #msg >= 255 then
    SyncLog('SendGuildTeamStats skipped', 'message too long (%d chars)', #msg)
    return
  end
  DoSendAddonMessage(ADDON_MSG_PREFIX, msg, 'GUILD')
  SyncLog('SendGuildTeamStats sent', '%d members, %d pts, %d chars', #members, totalPoints, #msg)
end

local function SendMyStats()
  SyncLog('SendMyStats called')
  local numMembers = GetNumGroupMembers and GetNumGroupMembers() or 0
  if numMembers < 1 then
    SyncLog('SendMyStats early exit', 'GetNumGroupMembers=%d (need party/raid)', numMembers)
    return
  end
  local myName = UnitName and UnitName('player')
  if not myName then
    SyncLog('SendMyStats early exit', 'UnitName(player) is nil')
    return
  end
  local data = GetPlayerStatsForSync()
  StoreMemberData(NormalizeName(myName), data)
  local msg = SerializeStats(data)
  if not msg then
    SyncLog('SendMyStats early exit', 'SerializeStats returned nil')
    return
  end
  if not (SendAddonMessage or (C_ChatInfo and C_ChatInfo.SendAddonMessage)) then
    SyncLog('SendMyStats early exit', 'SendAddonMessage / C_ChatInfo.SendAddonMessage not available')
    return
  end
  if #msg >= 255 then
    data.equipment = {}
    msg = SerializeStats(data)
  end
  if msg and #msg < 255 then
    DoSendAddonMessage(ADDON_MSG_PREFIX, msg, 'PARTY')
    SyncLog('SendMyStats sent', '%s L%d %s (%d chars)', myName, data.level or 0, data.class or '?', #msg)
  else
    SyncLog('SendMyStats skipped', 'message still too long after equipment strip (%d)', msg and #msg or 0)
  end
end

local frame = CreateFrame('Frame')
frame:RegisterEvent('GROUP_ROSTER_UPDATE')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:RegisterEvent('GUILD_ROSTER_UPDATE')
frame:RegisterEvent('CHAT_MSG_ADDON')

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  local ok, err = pcall(function()
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)
  end)
  SyncLog('Addon prefix', ok and 'registered' or ('failed: %s'):format(tostring(err)))
else
  SyncLog('Addon prefix', 'C_ChatInfo.RegisterAddonMessagePrefix not available')
end

frame:SetScript('OnEvent', function(self, event, ...)
  if event == 'GROUP_ROSTER_UPDATE' or event == 'PLAYER_ENTERING_WORLD' or event == 'GUILD_ROSTER_UPDATE' then
    SyncLog('Event', '%s', event)
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
    if prefix ~= ADDON_MSG_PREFIX then return end
    if not sender or sender == '' then return end

    SyncLog('CHAT_MSG_ADDON received', 'prefix=%s channel=%s sender=%s len=%d', prefix, channel, sender, msg and #msg or 0)

    if channel == 'PARTY' then
      SyncLog('PARTY raw msg', '%s', msg and msg:gsub('\t', ' | ') or 'nil')
      if not IsAllowedByGroupList then
        SyncLog('PARTY msg ignored', 'IsAllowedByGroupList not available')
        return
      end
      if not IsAllowedByGroupList(sender) then
        local list = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundNames) or {}
        local listStr = table.concat(list, ', ')
        local normSender = NormalizeName and NormalizeName(sender) or sender
        SyncLog('PARTY msg ignored', 'sender %s (norm=%s) not in group list [%s]', sender, tostring(normSender), listStr)
        return
      end
      local data = ParseStatsMessage(msg)
      if not data then
        SyncLog('PARTY msg ignored', 'ParseStatsMessage failed (msg len=%d)', msg and #msg or 0)
        return
      end
      local equipCount = 0
      if data.equipment then for _ in pairs(data.equipment) do equipCount = equipCount + 1 end end
      local p1 = data.professions and data.professions[1]
      local p2 = data.professions and data.professions[2]
      SyncLog('PARTY parsed', 'sender=%s race=%s class=%s level=%s pr1=%s pr2=%s equipSlots=%d',
        sender, tostring(data.race), tostring(data.class), tostring(data.level),
        p1 and (p1.name or '') or 'nil', p2 and (p2.name or '') or 'nil', equipCount)
      StoreMemberData(NormalizeName(sender), data)
    elseif channel == 'GUILD' then
      local teamData = ParseGuildTeamMessage(msg)
      if not teamData then
        SyncLog('GUILD msg ignored', 'ParseGuildTeamMessage failed (msg len=%d)', msg and #msg or 0)
        return
      end
      StoreGuildTeamData(sender, teamData)
    else
      SyncLog('CHAT_MSG_ADDON ignored', 'channel %s not PARTY/GUILD', tostring(channel))
    end
  end
end)

-- Expose for UI refresh after receiving data (e.g. GroupFoundSummary can call this)
function UltraFound_RequestGroupSync()
  SyncLog('UltraFound_RequestGroupSync called')
  SendMyStats()
  SendGuildTeamStats()
end
