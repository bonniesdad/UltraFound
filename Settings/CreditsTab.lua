-- Credits Tab Content - Same pattern and content as UltraHardcore Credits.md / CreditsTab
function UltraFound_InitializeCreditsTab(tabContents)
  if not tabContents or not tabContents[4] then return end
  if tabContents[4].initialized then return end
  tabContents[4].initialized = true

  local contentBackground = CreateFrame('Frame', nil, tabContents[4], 'BackdropTemplate')
  contentBackground:SetPoint('TOP', tabContents[4], 'TOP', 0, -60)
  contentBackground:SetPoint('LEFT', tabContents[4], 'LEFT', 10, 0)
  contentBackground:SetPoint('RIGHT', tabContents[4], 'RIGHT', -10, 0)
  contentBackground:SetPoint('BOTTOM', tabContents[4], 'BOTTOM', 0, -25)
  contentBackground:SetBackdrop({
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    tile = true,
    tileSize = 64,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  contentBackground:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
  contentBackground:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

  local contentBgW = contentBackground:GetWidth()
  local aboutAuthorW = (contentBgW and contentBgW > 100) and (contentBgW - 40) or 470
  local aboutAuthorFrame = UHC_CreateAboutAuthorSection(
    contentBackground, 'TOPLEFT', contentBackground, 'TOPLEFT', 20, -20, aboutAuthorW
  )

  local familyTitle = contentBackground:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  familyTitle:SetPoint('TOP', aboutAuthorFrame, 'BOTTOM', 0, 0)
  familyTitle:SetText('Ultra Family Addons')
  familyTitle:SetTextColor(0.922, 0.871, 0.761)

  local ADDON_BOX_SIZE = 80
  local ADDON_BOX_GAP = 12
  local ADDON_TITLE_GAP = 12
  -- Only show the currently released addons in the Ultra family.
  local addonTitles = { 'Ultra HC', 'Ultra Stats', 'Ultra Found' }
  -- Specific icons for each addon
  local addonTextures = {
    'Interface\\AddOns\\UltraFound\\Textures\\Ultra HC Icon.png', -- Ultra Hardcore
    'Interface\\AddOns\\UltraFound\\Textures\\stats.png',         -- Ultra Statistics
    'Interface\\AddOns\\UltraFound\\Textures\\bonnie-round.png',  -- Ultra Found
  }
  local contentW = 490
  local numAddons = #addonTitles
  local rowWidth = (ADDON_BOX_SIZE * numAddons) + (ADDON_BOX_GAP * (numAddons - 1))
  local rowStartX = (contentW - rowWidth) / 2 + 10

  local addonRowBottom = familyTitle

  for i = 1, numAddons do
    local colX = rowStartX + (i - 1) * (ADDON_BOX_SIZE + ADDON_BOX_GAP)

    local titleLabel = contentBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    titleLabel:SetPoint('TOP', familyTitle, 'BOTTOM', 0, -ADDON_TITLE_GAP)
    titleLabel:SetPoint('LEFT', contentBackground, 'LEFT', colX, 0)
    titleLabel:SetWidth(ADDON_BOX_SIZE)
    titleLabel:SetJustifyH('CENTER')
    titleLabel:SetText(addonTitles[i])
    titleLabel:SetTextColor(0.922, 0.871, 0.761)

    local box = CreateFrame('Frame', nil, contentBackground, 'BackdropTemplate')
    box:SetSize(ADDON_BOX_SIZE, ADDON_BOX_SIZE)
    box:SetPoint('TOP', titleLabel, 'BOTTOM', 0, -ADDON_TITLE_GAP)
    box:SetPoint('LEFT', contentBackground, 'LEFT', colX, 0)
    local tex = box:CreateTexture(nil, 'BACKGROUND')
    tex:SetTexture(addonTextures[i])
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- if i == 1 then
    --   -- Ultra Hardcore icon: keep full size in the square
    --   tex:SetAllPoints(box)
    -- else
      -- Ultra Statistics and Ultra Found: scale down slightly within the square
      tex:SetPoint('CENTER', box, 'CENTER', 0, 0)
      tex:SetSize(ADDON_BOX_SIZE * 0.9, ADDON_BOX_SIZE * 0.9)
    -- end
    box:SetBackdrop({
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropBorderColor(0.6, 0.5, 0.35, 0.9)

    addonRowBottom = box
  end

  local joinDeveloperText = contentBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  joinDeveloperText:SetPoint('TOP', addonRowBottom, 'BOTTOM', -90, -30)
  joinDeveloperText:SetText(
    'Join the developers\' Discord community and Twitch channel to help support us and have your say on the future of this addon!'
  )
  joinDeveloperText:SetJustifyH('CENTER')
  joinDeveloperText:SetTextColor(0.95, 0.95, 0.9)
  joinDeveloperText:SetWidth(360)
  joinDeveloperText:SetNonSpaceWrap(true)

  local discordButton = UHC_CreateDiscordInviteButton(
    contentBackground, 'TOP', joinDeveloperText, 'BOTTOM', 0, -10, 220, 24, 'Discord Invite Link'
  )
  discordButton:ClearAllPoints()
  discordButton:SetPoint('TOP', joinDeveloperText, 'BOTTOM', 0, -10)
  discordButton:SetPoint('CENTER', tabContents[4], 'CENTER', 0, 0)

  local twitchButton = UHC_CreateTwitchInviteButton(
    contentBackground, 'TOP', discordButton, 'BOTTOM', 0, 0, 220, 28, 'Twitch Channel'
  )
  twitchButton:ClearAllPoints()
  twitchButton:SetPoint('TOP', discordButton, 'BOTTOM', 0, 0)
  twitchButton:SetPoint('CENTER', tabContents[4], 'CENTER', 0, 0)
end
