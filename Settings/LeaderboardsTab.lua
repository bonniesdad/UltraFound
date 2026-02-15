-- Leaderboards Tab - Shows statistics from UltraStatisticsDB for all characters with a points system

local TABLE_LEFT_PADDING = 20
local ROW_HEIGHT = 22
local NUM_VISIBLE_ROWS = 5
local COLUMN_GAP = 4

local GUILD_CARD_BACKDROP = {
  bgFile = 'Interface\\AddOns\\UltraFound\\Textures\\bg_druid.png',
  edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
  tile = false,
  tileSize = 1,
  edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function formatNumberWithCommas(number)
  if type(number) ~= 'number' then
    number = tonumber(number) or 0
  end
  local formatted = tostring(math.floor(math.abs(number)))
  local k
  while true do
    formatted, k = string.gsub(formatted, '^(%d+)(%d%d%d)', '%1,%2')
    if k == 0 then break end
  end
  return (number < 0) and ('-' .. formatted) or formatted
end

local function formatMoney(copper)
  copper = tonumber(copper) or 0
  if copper < 0 then copper = -copper end
  if copper == 0 then return '-' end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = math.floor(copper % 100)
  local parts = {}
  local iconSize = 10
  if g > 0 then
    table.insert(parts, string.format('%d|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:0:0|t', g, iconSize, iconSize))
  end
  if s > 0 then
    table.insert(parts, string.format('%d|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:0:0|t', s, iconSize, iconSize))
  end
  if c > 0 then
    table.insert(parts, string.format('%d|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:0:0|t', c, iconSize, iconSize))
  end
  return (#parts > 0) and table.concat(parts, ' ') or '-'
end

local function getCharacterName(guid)
  if GetPlayerInfoByGUID then
    local locClass, engClass, locRace, engRace, gender, name, server = GetPlayerInfoByGUID(guid)
    if name and name ~= '' then
      if server and server ~= '' then
        return name .. '-' .. server
      end
      return name
    end
  end
  -- Fallback: truncate GUID for display
  if type(guid) == 'string' and #guid > 12 then
    return '...' .. string.sub(guid, -8)
  end
  return 'Unknown'
end

local function calculatePoints(level, enemiesSlain, dungeonsCompleted, goldGained)
  local levelPts = (tonumber(level) or 0) * 100
  local enemiesPts = math.floor((tonumber(enemiesSlain) or 0) / 10)
  local dungeonsPts = (tonumber(dungeonsCompleted) or 0) * 75
  -- goldGained is in copper; 10g = 100000 copper
  local goldPts = math.floor((tonumber(goldGained) or 0) / 100000)
  return levelPts + enemiesPts + dungeonsPts + goldPts
end

local function buildLeaderboardData()
  local data = {}
  local db = _G.UltraStatisticsDB
  if not db or not db.characterStats or type(db.characterStats) ~= 'table' then
    return data
  end

  local currentGUID = UnitGUID and UnitGUID('player')
  local currentLevel = UnitLevel and UnitLevel('player') or 0

  for guid, stats in pairs(db.characterStats) do
    if stats and type(stats) == 'table' then
      local level = (guid == currentGUID) and currentLevel or nil
      local enemiesSlain = stats.enemiesSlain or 0
      local dungeonsCompleted = stats.dungeonsCompleted or 0
      local highestCritValue = stats.highestCritValue or 0
      local healthPotionsUsed = stats.healthPotionsUsed or 0
      local goldGained = stats.goldGained or 0

      local points = calculatePoints(level or 0, enemiesSlain, dungeonsCompleted, goldGained)

      table.insert(data, {
        name = getCharacterName(guid),
        guid = guid,
        level = level,
        enemiesSlain = enemiesSlain,
        dungeonsCompleted = dungeonsCompleted,
        highestCritValue = highestCritValue,
        healthPotionsUsed = healthPotionsUsed,
        goldGained = goldGained,
        points = points,
      })
    end
  end

  -- Sort by points descending
  table.sort(data, function(a, b) return a.points > b.points end)
  return data
end

local function getTeamNames()
  local names = {}
  local playerName = UnitName and UnitName('player')
  if playerName and playerName ~= '' then
    table.insert(names, playerName)
  end
  for _, name in ipairs(GLOBAL_SETTINGS.groupFoundNames or {}) do
    if name and name ~= '' then
      table.insert(names, name)
    end
  end
  return names
end

local function buildTeamLeaderboardData()
  local allData = buildLeaderboardData()
  local teamNames = getTeamNames()
  if #teamNames == 0 then return allData end
  local nameToRow = {}
  for _, row in ipairs(allData) do
    local norm = NormalizeName and NormalizeName(row.name) or string.lower(row.name or '')
    if norm ~= '' then nameToRow[norm] = row end
  end
  local result = {}
  for _, name in ipairs(teamNames) do
    local norm = NormalizeName and NormalizeName(name) or string.lower(name or '')
    local row = nameToRow[norm]
    if row then
      table.insert(result, row)
    else
      local currentGUID = UnitGUID and UnitGUID('player')
      local isPlayer = norm == (NormalizeName and NormalizeName(UnitName and UnitName('player')) or string.lower(UnitName and UnitName('player') or ''))
      local level = (isPlayer and UnitLevel) and UnitLevel('player') or nil
      table.insert(result, {
        name = name,
        guid = nil,
        level = level,
        enemiesSlain = 0,
        dungeonsCompleted = 0,
        highestCritValue = 0,
        healthPotionsUsed = 0,
        goldGained = 0,
        points = 0,
      })
    end
  end
  table.sort(result, function(a, b) return (a.points or 0) > (b.points or 0) end)
  return result
end

local function buildGuildLeaderboardData()
  -- Returns array of teams: { senderName?, members = [...], totalPoints }
  local teams = {}
  local memberData = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundMemberData) or {}

  -- Our team
  local db = _G.UltraStatisticsDB
  local nameToPoints = {}
  if db and db.characterStats and type(db.characterStats) == 'table' then
    local currentGUID = UnitGUID and UnitGUID('player')
    local currentLevel = UnitLevel and UnitLevel('player') or 0
    for guid, stats in pairs(db.characterStats) do
      if stats and type(stats) == 'table' then
        local name = getCharacterName(guid)
        local norm = NormalizeName and NormalizeName(name) or string.lower(name or '')
        if norm and norm ~= '' then
          local level = (guid == currentGUID) and currentLevel or nil
          local pts = calculatePoints(level or 0, stats.enemiesSlain or 0, stats.dungeonsCompleted or 0, stats.goldGained or 0)
          if not nameToPoints[norm] then nameToPoints[norm] = pts end
        end
      end
    end
  end

  local ourMembers = {}
  local playerName = UnitName and UnitName('player')
  if playerName then
    local norm = NormalizeName and NormalizeName(playerName) or string.lower(playerName or '')
    table.insert(ourMembers, {
      name = playerName,
      race = (UnitRace and select(1, UnitRace('player'))) or '—',
      class = (UnitClass and select(1, UnitClass('player'))) or '—',
      level = UnitLevel and UnitLevel('player') or nil,
      points = nameToPoints[norm] or 0,
    })
  end
  for _, name in ipairs(GLOBAL_SETTINGS.groupFoundNames or {}) do
    if name and name ~= '' then
      local key = NormalizeName and NormalizeName(name) or string.lower(name or '')
      local data = memberData[key] or {}
      table.insert(ourMembers, {
        name = name,
        race = data.race or '—',
        class = data.class or '—',
        level = data.level,
        points = nameToPoints[key] or 0,
      })
    end
  end

  local ourTotalPoints = 0
  for _, m in ipairs(ourMembers) do
    ourTotalPoints = ourTotalPoints + (m.points or 0)
  end

  if #ourMembers > 0 then
    table.insert(teams, { senderName = playerName, members = ourMembers, totalPoints = ourTotalPoints })
  end

  -- Teams from guild addon messages
  local guildTeams = GLOBAL_SETTINGS and GLOBAL_SETTINGS.guildTeamsData or {}
  local myNorm = NormalizeName and NormalizeName(playerName) or string.lower(playerName or '')
  for key, team in pairs(guildTeams) do
    if team and team.members and #team.members > 0 and key ~= myNorm then
      table.insert(teams, {
        senderName = team.senderName or key,
        members = team.members,
        totalPoints = team.totalPoints or 0,
      })
    end
  end

  table.sort(teams, function(a, b) return (a.totalPoints or 0) > (b.totalPoints or 0) end)
  return teams
end

function UltraFound_InitializeLeaderboardsTab(tabContents)
  if not tabContents or not tabContents[2] then return end
  local content = tabContents[2]
  if content.initialized and content.refreshGuildLeaderboard then
    content.refreshGuildLeaderboard()
    return
  end
  content.initialized = true

  local title = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  title:SetPoint('TOP', content, 'TOP', 0, -60)
  title:SetText('Leaderboards')
  title:SetTextColor(0.922, 0.871, 0.761)

  local subtitle = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -4)
  subtitle:SetText('Stats from Ultra Statistics addon')
  subtitle:SetTextColor(0.75, 0.75, 0.75)

  local FRAME_BACKDROP = {
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    tile = true,
    tileSize = 64,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  }

  -- Character Leaderboard frame (rows = team size when team configured, else up to NUM_VISIBLE_ROWS)
  local teamData = buildTeamLeaderboardData()
  local teamNames = getTeamNames()
  local numRows = (#teamNames > 0) and #teamData or math.min(NUM_VISIBLE_ROWS, #teamData)
  numRows = math.max(1, math.min(numRows, 10))
  local charLeaderboardFrame = CreateFrame('Frame', nil, content, 'BackdropTemplate')
  charLeaderboardFrame:SetPoint('TOP', subtitle, 'BOTTOM', 0, -12)
  charLeaderboardFrame:SetPoint('LEFT', content, 'LEFT', 10, 0)
  charLeaderboardFrame:SetPoint('RIGHT', content, 'RIGHT', -10, 0)
  local charTableHeight = (ROW_HEIGHT + 2) * numRows + ROW_HEIGHT + 16
  charLeaderboardFrame:SetHeight(charTableHeight)
  charLeaderboardFrame:SetBackdrop(FRAME_BACKDROP)
  charLeaderboardFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
  charLeaderboardFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

  local charTableFrame = CreateFrame('Frame', nil, charLeaderboardFrame)
  charTableFrame:SetPoint('TOPLEFT', charLeaderboardFrame, 'TOPLEFT', TABLE_LEFT_PADDING, -8)
  charTableFrame:SetPoint('RIGHT', charLeaderboardFrame, 'RIGHT', -20, 0)
  charTableFrame:SetHeight(charTableHeight - 16)

  local bgW = charLeaderboardFrame:GetWidth()
  local tableWidth = (bgW and bgW > 100) and (bgW - TABLE_LEFT_PADDING - 20) or 460

  local COLUMNS = {
    { key = 'name', label = 'Character', weight = 2, align = 'LEFT' },
    { key = 'level', label = 'Lvl', weight = 0.6, align = 'CENTER' },
    { key = 'enemiesSlain', label = 'Kills', weight = 1, align = 'RIGHT' },
    { key = 'dungeonsCompleted', label = 'Dungs', weight = 1, align = 'RIGHT' },
    { key = 'highestCritValue', label = 'Crit', weight = 1, align = 'RIGHT' },
    { key = 'healthPotionsUsed', label = 'Pots', weight = 0.8, align = 'RIGHT' },
    { key = 'goldGained', label = 'Gold', weight = 1.2, align = 'RIGHT' },
    { key = 'points', label = 'Pts', weight = 0.8, align = 'RIGHT' },
  }

  local function getColumnWidths(totalWidth)
    local weights = 0
    for _, col in ipairs(COLUMNS) do
      weights = weights + col.weight
    end
    local avail = totalWidth - (COLUMN_GAP * (#COLUMNS - 1))
    local widths = {}
    for i, col in ipairs(COLUMNS) do
      widths[i] = math.floor(avail * col.weight / weights)
    end
    return widths
  end

  local colWidths = getColumnWidths(tableWidth)

  local headerRow = CreateFrame('Frame', nil, charTableFrame)
  headerRow:SetPoint('TOPLEFT', charTableFrame, 'TOPLEFT', 0, 0)
  headerRow:SetSize(tableWidth, ROW_HEIGHT)
  local xPos = 0
  for i, col in ipairs(COLUMNS) do
    local w = colWidths[i]
    local lbl = headerRow:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    lbl:SetPoint('TOPLEFT', headerRow, 'TOPLEFT', xPos, -4)
    lbl:SetWidth(w)
    lbl:SetJustifyH(col.align == 'CENTER' and 'CENTER' or (col.align == 'RIGHT' and 'RIGHT' or 'LEFT'))
    lbl:SetText(col.label)
    lbl:SetTextColor(0.9, 0.85, 0.6)
    xPos = xPos + w + COLUMN_GAP
  end

  local function formatValue(key, value, row)
    if value == nil then return '—' end
    if key == 'name' then return tostring(value) end
    if key == 'goldGained' then return formatMoney(value) end
    if key == 'level' and row.level == nil then return '—' end
    return formatNumberWithCommas(value)
  end

  local prevRow = headerRow

  if #teamData == 0 then
    local emptyLabel = charTableFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    emptyLabel:SetPoint('TOP', headerRow, 'BOTTOM', 0, -12)
    emptyLabel:SetText('Add group members in X Found Mode to see your team. Install Ultra Statistics to track stats.')
    emptyLabel:SetTextColor(0.7, 0.7, 0.7)
  else
    for i = 1, numRows do
      local row = teamData[i]
      local rowFrame = CreateFrame('Frame', nil, charTableFrame)
      rowFrame:SetPoint('TOPLEFT', prevRow, 'BOTTOMLEFT', 0, -2)
      rowFrame:SetSize(tableWidth, ROW_HEIGHT)
      prevRow = rowFrame

      xPos = 0
      for j, col in ipairs(COLUMNS) do
        local w = colWidths[j]
        local val = row[col.key]
        local text = formatValue(col.key, val, row)
        local cell = rowFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        cell:SetPoint('TOPLEFT', rowFrame, 'TOPLEFT', xPos, -4)
        cell:SetWidth(w)
        cell:SetJustifyH(col.align == 'CENTER' and 'CENTER' or (col.align == 'RIGHT' and 'RIGHT' or 'LEFT'))
        cell:SetText(text)
        cell:SetTextColor(0.92, 0.92, 0.92)
        xPos = xPos + w + COLUMN_GAP
      end
    end
  end

  -- Guild Leaderboards title (between the two tables)
  local guildTitle = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  guildTitle:SetPoint('TOP', charLeaderboardFrame, 'BOTTOM', 0, -24)
  guildTitle:SetText('Guild Leaderboards')
  guildTitle:SetTextColor(0.922, 0.871, 0.761)

  -- Guild Leaderboards frame (background, same as character table)
  local guildLeaderboardFrame = CreateFrame('Frame', nil, content, 'BackdropTemplate')
  guildLeaderboardFrame:SetPoint('TOP', guildTitle, 'BOTTOM', 0, -8)
  guildLeaderboardFrame:SetPoint('LEFT', content, 'LEFT', 8, 0)
  guildLeaderboardFrame:SetPoint('RIGHT', content, 'RIGHT', -8, 0)
  guildLeaderboardFrame:SetPoint('BOTTOM', content, 'BOTTOM', 0, -30)
  guildLeaderboardFrame:SetBackdrop(FRAME_BACKDROP)
  guildLeaderboardFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
  guildLeaderboardFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

  -- Scroll frame inside the backdrop (cards live in scroll child)
  local guildScrollFrame = CreateFrame('ScrollFrame', nil, guildLeaderboardFrame, 'UIPanelScrollFrameTemplate')
  guildScrollFrame:SetPoint('TOPLEFT', guildLeaderboardFrame, 'TOPLEFT', 8, -8)
  guildScrollFrame:SetPoint('BOTTOMRIGHT', guildLeaderboardFrame, 'BOTTOMRIGHT', -29, 8)

  local guildScrollChild = CreateFrame('Frame', nil, guildScrollFrame)
  guildScrollFrame:SetScrollChild(guildScrollChild)

  local function refreshGuildLeaderboardCards()
    -- Clear existing children
    for _, child in ipairs({ guildScrollChild:GetChildren() }) do
      child:Hide()
      child:SetParent(nil)
    end

    local guildTeams = buildGuildLeaderboardData()
    local cardPadding = 14
    local cardGap = 12
    local rowHeight = 22
    local totalScrollHeight = 0
    local playerName = UnitName and UnitName('player')

    if #guildTeams == 0 then
      local emptyCard = CreateFrame('Frame', nil, guildScrollChild, 'BackdropTemplate')
      emptyCard:SetPoint('TOPLEFT', guildScrollChild, 'TOPLEFT', 0, 0)
      emptyCard:SetPoint('LEFT', guildScrollChild, 'LEFT', 0, 0)
      emptyCard:SetPoint('RIGHT', guildScrollChild, 'RIGHT', 0, 0)
      emptyCard:SetHeight(65)
      emptyCard:SetBackdrop(GUILD_CARD_BACKDROP)
      emptyCard:SetBackdropColor(0.9, 0.9, 0.9, 0.95)
      emptyCard:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9)
      local emptyText = emptyCard:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
      emptyText:SetPoint('CENTER', emptyCard, 'CENTER', 0, 0)
      emptyText:SetText('Add group members in X Found Mode to see your group total. Guild teammates with UltraFound will appear here when they share their teams.')
      emptyText:SetTextColor(0.7, 0.7, 0.7)
      totalScrollHeight = 65
    else
      local prevCard = nil
      for _, team in ipairs(guildTeams) do
        local members = team.members or {}
        local totalPoints = team.totalPoints or 0
        local senderName = team.senderName

        local card = CreateFrame('Frame', nil, guildScrollChild, 'BackdropTemplate')
        if prevCard then
          card:SetPoint('TOPLEFT', prevCard, 'BOTTOMLEFT', 0, -cardGap)
        else
          card:SetPoint('TOPLEFT', guildScrollChild, 'TOPLEFT', 0, 0)
        end
        card:SetPoint('LEFT', guildScrollChild, 'LEFT', 0, 0)
        card:SetPoint('RIGHT', guildScrollChild, 'RIGHT', 0, 0)
        local hasTeamLabel = false
        local myNorm = NormalizeName and NormalizeName(playerName) or string.lower(playerName or '')
        local senderNorm = senderName and (NormalizeName and NormalizeName(senderName) or string.lower(senderName or ''))
        if senderName and senderNorm ~= myNorm then
          hasTeamLabel = true
        end
        card:SetBackdrop(GUILD_CARD_BACKDROP)
        card:SetBackdropColor(0.9, 0.9, 0.9, 0.95)
        card:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9)

        local prevRow = nil
        local topOffset = cardPadding
        if hasTeamLabel then
          local teamLabel = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
          teamLabel:SetPoint('TOPLEFT', card, 'TOPLEFT', cardPadding, -cardPadding)
          teamLabel:SetText(senderName .. "'s Team")
          teamLabel:SetTextColor(0.75, 0.7, 0.6)
          prevRow = teamLabel
          topOffset = 4
        end
        for _, m in ipairs(members) do
          local rowFrame = CreateFrame('Frame', nil, card)
          rowFrame:SetPoint('LEFT', card, 'LEFT', 0, 0)
          rowFrame:SetPoint('RIGHT', card, 'RIGHT', -90, 0)
          rowFrame:SetHeight(rowHeight)
          if prevRow then
            rowFrame:SetPoint('TOP', prevRow, 'BOTTOM', 0, -topOffset)
          else
            rowFrame:SetPoint('TOP', card, 'TOP', 0, -cardPadding)
          end
          topOffset = 0
          prevRow = rowFrame

          local lvl = m.level and tostring(m.level) or '—'
          local ptsStr = (m.points ~= nil) and (formatNumberWithCommas(tonumber(m.points) or 0) .. ' pts') or '—'
          local detailStr = ' - Lvl ' .. lvl .. ' ' .. (m.race or '—') .. ' ' .. (m.class or '—')

          local nameText = rowFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
          nameText:SetPoint('TOPLEFT', rowFrame, 'TOPLEFT', cardPadding, 0)
          nameText:SetText(m.name)
          nameText:SetTextColor(0.95, 0.92, 0.85)

          local detailText = rowFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
          detailText:SetPoint('LEFT', nameText, 'RIGHT', 0, 0)
          detailText:SetText(detailStr)
          detailText:SetTextColor(0.8, 0.8, 0.8)

          local memberPtsText = rowFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
          memberPtsText:SetPoint('TOPRIGHT', rowFrame, 'TOPRIGHT', -cardPadding, 0)
          memberPtsText:SetJustifyH('RIGHT')
          memberPtsText:SetText(ptsStr)
          memberPtsText:SetTextColor(0.85, 0.8, 0.55)
        end

        local pointsText = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        pointsText:SetPoint('TOPRIGHT', card, 'TOPRIGHT', -cardPadding, -cardPadding)
        pointsText:SetJustifyH('RIGHT')
        pointsText:SetText(formatNumberWithCommas(totalPoints) .. ' pts')
        pointsText:SetTextColor(0.9, 0.85, 0.5)

        local cardHeight = cardPadding + (hasTeamLabel and (14 + 4) or 0) + (#members * rowHeight) + cardPadding
        card:SetHeight(cardHeight)
        totalScrollHeight = totalScrollHeight + (prevCard and cardGap or 0) + cardHeight
        prevCard = card
      end
    end

    local scrollFrameW = guildScrollFrame:GetWidth()
    local scrollChildW = (scrollFrameW and scrollFrameW > 50) and (scrollFrameW - 5) or 475
    guildScrollChild:SetSize(scrollChildW, totalScrollHeight)
  end

  content.refreshGuildLeaderboard = refreshGuildLeaderboardCards
  refreshGuildLeaderboardCards()
end
