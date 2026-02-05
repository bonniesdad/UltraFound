-- Save settings for current character
function SaveCharacterSettings(settings)
  local characterGUID = UnitGUID('player')

  if not UltraFoundDB.characterSettings then
    UltraFoundDB.characterSettings = {}
  end

  UltraFoundDB.characterSettings[characterGUID] = settings
end
