addonName = ...
UltraFound = CreateFrame('Frame')

-- DB Values
GLOBAL_SETTINGS = {} -- Will be populated by LoadDBData()
UltraFound:RegisterEvent('ADDON_LOADED')
UltraFound:RegisterEvent('PLAYER_LOGIN')
UltraFound:RegisterEvent('PLAYER_LOGOUT')

UltraFound:SetScript('OnEvent', function(self, event, ...)
  if event == 'PLAYER_LOGIN' then
    LoadDBData()
  end
end)
