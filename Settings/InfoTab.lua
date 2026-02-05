-- Info Tab Content - Same pattern as UltraHardcore
function UltraFound_InitializeInfoTab(tabContents)
  if not tabContents or not tabContents[2] then return end
  if tabContents[2].initialized then return end
  tabContents[2].initialized = true

  local content = tabContents[2]

  local philosophyText = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  philosophyText:SetPoint('TOP', content, 'TOP', 0, -70)
  philosophyText:SetWidth(300)
  local version = '1.0.0'
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata('UltraFound', 'Version') or version
  elseif GetAddOnMetadata then
    version = GetAddOnMetadata('UltraFound', 'Version') or version
  end
  philosophyText:SetText('Ultra Found Addon\nVersion: ' .. version)
  philosophyText:SetJustifyH('CENTER')
  philosophyText:SetNonSpaceWrap(true)

  local bugReportText = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  bugReportText:SetPoint('TOP', philosophyText, 'BOTTOM', 0, -10)
  bugReportText:SetText(
    'Found a bug or have suggestions?\n\nJoin the developers discord community to have your say on the future of this addon!'
  )
  bugReportText:SetJustifyH('CENTER')
  bugReportText:SetTextColor(0.95, 0.95, 0.9)
  bugReportText:SetWidth(300)
  bugReportText:SetNonSpaceWrap(true)

  local discordButton = UHC_CreateDiscordInviteButton(
    content, 'TOP', bugReportText, 'BOTTOM', 0, -10, 220, 24, 'Discord Invite Link'
  )

  local patchNotesTitle = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  patchNotesTitle:SetPoint('TOP', discordButton, 'BOTTOM', 0, -30)
  patchNotesTitle:SetText('Patch Notes')
  patchNotesTitle:SetJustifyH('CENTER')
  patchNotesTitle:SetTextColor(1, 1, 0.5)

  local patchNotesFrame = CreateFrame('Frame', nil, content, 'BackdropTemplate')
  patchNotesFrame:SetPoint('TOP', patchNotesTitle, 'BOTTOM', 0, -17)
  patchNotesFrame:SetPoint('LEFT', content, 'LEFT', 10, 0)
  patchNotesFrame:SetPoint('RIGHT', content, 'RIGHT', -10, 0)
  patchNotesFrame:SetHeight(380)
  patchNotesFrame:SetBackdrop({
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    tile = true,
    tileSize = 64,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  patchNotesFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
  patchNotesFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

  UltraFound_CreatePatchNotesDisplay(patchNotesFrame, 360, 360, 10, -10)
end
