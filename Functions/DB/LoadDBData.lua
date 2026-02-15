-- Load saved settings on login
function LoadDBData()
  if not UltraFoundDB then
    UltraFoundDB = {}
  end

  -- Initialize character settings if they don't exist
  if not UltraFoundDB.characterSettings then
    UltraFoundDB.characterSettings = {}
  end

  local defaultSettings = {
    guildSelfFound = false,
    groupSelfFound = false,
    groupFoundNames = {},
    groupFoundRoles = {}, -- [normalizedCharacterName] = "TANK"|"HEALER"|"DPS"
    groupFoundOffSpecRoles = {}, -- [normalizedCharacterName] = "TANK"|"HEALER"|"DPS"
    groupFoundMemberData = {}, -- [normalizedCharacterName] = { race, class, level, talentSpec, professions, equipment = { slotName = itemId } }
    guildTeamsData = {}, -- [normalizedSenderName] = { senderName, members = [{name,race,class,level}], totalPoints } from addon messages
    lastOpenedSettingsTab = 1,
  }

  local characterGUID = UnitGUID('player')
  if not UltraFoundDB.characterSettings[characterGUID] then
    UltraFoundDB.characterSettings[characterGUID] = defaultSettings
  end

  for settingName, settingValue in pairs(defaultSettings) do
    if UltraFoundDB.characterSettings[characterGUID][settingName] == nil then
      UltraFoundDB.characterSettings[characterGUID][settingName] = settingValue
    end
  end

  GLOBAL_SETTINGS = UltraFoundDB.characterSettings[characterGUID]
end
