local TEXTURE_PATH = 'Interface\\AddOns\\UltraFound\\Textures'

function UltraFound_InitializeXFoundModeTab(tabContents)
  if not tabContents or not tabContents[1] then return end
  if tabContents[1].initialized then return end
  tabContents[1].initialized = true

  local content = tabContents[1]
  local contentWidth = 400
  -- Extra top offset so banners sit below the tab bar (only this tab needs it)
  local topOffset = 50
  local padding = 10
  local bannerGap = 8
  local contentHeight = 560 - topOffset
  local bannerHeight = (contentHeight - (2 * padding) - (2 * bannerGap)) / 3

  -- Three banners stacked: Self Found, Group Found, Guild Found
  local bannerConfigs = {
    {
      key = 'self',
      label = 'Self Found',
      texture = nil,
      backdropColor = { 0.15, 0.2, 0.15, 0.95 },
      borderColor = { 0.4, 0.5, 0.4, 0.9 },
    },
    {
      key = 'group',
      label = 'Group Found',
      texture = TEXTURE_PATH .. '\\group-found-banner.png',
      borderColor = { 0.5, 0.5, 0.5, 0.9 },
    },
    {
      key = 'guild',
      label = 'Guild Found',
      texture = TEXTURE_PATH .. '\\guild-found-banner.png',
      borderColor = { 0.5, 0.5, 0.5, 0.9 },
    },
  }

  local prevBanner
  for i, cfg in ipairs(bannerConfigs) do
    local banner = CreateFrame('Frame', nil, content, 'BackdropTemplate')
    banner:SetHeight(bannerHeight)
    banner:SetPoint('LEFT', content, 'LEFT', padding, 0)
    banner:SetPoint('RIGHT', content, 'RIGHT', -padding, 0)
    if prevBanner then
      banner:SetPoint('TOP', prevBanner, 'BOTTOM', 0, -bannerGap)
    else
      banner:SetPoint('TOP', content, 'TOP', 0, -topOffset - padding)
    end
    prevBanner = banner

    if cfg.texture then
      local tex = banner:CreateTexture(nil, 'BACKGROUND')
      tex:SetAllPoints(banner)
      tex:SetTexture(cfg.texture)
      tex:SetTexCoord(0, 1, 0, 1)
    end

    banner:SetBackdrop({
      bgFile = cfg.texture and nil or 'Interface\\Buttons\\WHITE8x8',
      edgeFile = 'Interface\\Buttons\\WHITE8x8',
      tile = false,
      tileSize = 0,
      edgeSize = 2,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if cfg.texture then
      banner:SetBackdropColor(0, 0, 0, 0.4)
    else
      banner:SetBackdropColor(cfg.backdropColor[1], cfg.backdropColor[2], cfg.backdropColor[3], cfg.backdropColor[4])
    end
    banner:SetBackdropBorderColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])

    local label = banner:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    label:SetPoint('CENTER', banner, 'CENTER', 0, 0)
    label:SetText(cfg.label)
    label:SetTextColor(0.922, 0.871, 0.761)
  end
end
