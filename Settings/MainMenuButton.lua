-- Game menu button - same pattern as UltraHardcore, opens Ultra Found settings
local button = _G.GameMenuButtonUltraFound
if not button then
  button = CreateFrame('Button', 'GameMenuButtonUltraFound', UIParent, 'GameMenuButtonTemplate')
end

button:Hide()

local function SkinUltraFoundButton()
  if button._ufSkinned then return end
  button._ufSkinned = true
  button:SetSize(160, 28)
  if button.GetFontString and button:GetFontString() then
    button:GetFontString():Hide()
  end
  if button.Text and button.Text.Hide then
    button.Text:Hide()
  end

  local label = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  label:SetPoint('LEFT', button, 'LEFT', 34, 0)
  label:SetPoint('RIGHT', button, 'RIGHT', -34, 0)
  label:SetJustifyH('CENTER')
  label:SetText('Ultra Found')
  label:SetTextColor(1, 0.82, 0.2)
  button._ufLabel = label

  local hover = button:CreateTexture(nil, 'HIGHLIGHT')
  hover:SetAllPoints(button)
  hover:SetColorTexture(1, 1, 1, 0.06)
  button:SetScript('OnEnter', function()
    if button._ufLabel then button._ufLabel:SetTextColor(1, 0.9, 0.35) end
  end)
  button:SetScript('OnLeave', function()
    if button._ufLabel then button._ufLabel:SetTextColor(1, 0.82, 0.2) end
  end)
  button:SetScript('OnMouseDown', function()
    if button._ufLabel then
      button._ufLabel:ClearAllPoints()
      button._ufLabel:SetPoint('LEFT', button, 'LEFT', 34, -1)
      button._ufLabel:SetPoint('RIGHT', button, 'RIGHT', -34, -1)
    end
  end)
  button:SetScript('OnMouseUp', function()
    if button._ufLabel then
      button._ufLabel:ClearAllPoints()
      button._ufLabel:SetPoint('LEFT', button, 'LEFT', 34, 0)
      button._ufLabel:SetPoint('RIGHT', button, 'RIGHT', -34, 0)
    end
  end)
end

local function PositionUltraFoundButton()
  SkinUltraFoundButton()
  button:ClearAllPoints()
  button:SetPoint('TOP', GameMenuFrame, 'BOTTOM', 0, -8)
  button:SetFrameStrata(GameMenuFrame:GetFrameStrata() or 'DIALOG')
  button:SetFrameLevel((GameMenuFrame:GetFrameLevel() or 0) + 10)
end

button:SetScript('OnClick', function()
  HideUIPanel(GameMenuFrame)
  ToggleUltraFoundSettings()
end)

GameMenuFrame:HookScript('OnShow', function()
  PositionUltraFoundButton()
  button:Show()
end)
GameMenuFrame:HookScript('OnHide', function()
  button:Hide()
end)
