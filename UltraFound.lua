addonName = ...
UltraFound = CreateFrame('Frame')

-- DB Values
ULTRA_FOUND_GLOBAL_SETTINGS = {} -- Will be populated by UltraFound_LoadDBData()
UltraFound:RegisterEvent('ADDON_LOADED')
UltraFound:RegisterEvent('PLAYER_LOGIN')
UltraFound:RegisterEvent('PLAYER_LOGOUT')

UltraFound:SetScript('OnEvent', function(self, event, ...)
  if event == 'PLAYER_LOGIN' then
    UltraFound_LoadDBData()
  end
end)
