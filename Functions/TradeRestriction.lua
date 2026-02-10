-- Trade/mail/auction restriction logic for Self Found, Group Found, Guild Found.
-- Uses NormalizeName (from Utils) and GLOBAL_SETTINGS from LoadDBData.

-- Helper: check if a name is allowed by the saved group list
function IsAllowedByGroupList(name)
  local normalized = NormalizeName(name)
  if not normalized then
    return false
  end
  local list = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundNames) or {}
  for _, allowed in ipairs(list) do
    if NormalizeName(allowed) == normalized then
      return true
    end
  end
  return false
end



local tradeOverlay = nil

local function EnsureTradeOverlay()
  if tradeOverlay and tradeOverlay:GetParent() == TradeFrame then
    return tradeOverlay
  end
  if not TradeFrame then
    return nil
  end
  tradeOverlay = CreateFrame('Frame', 'UltraFoundTradeOverlay', TradeFrame)
  tradeOverlay:SetAllPoints(TradeFrame)
  tradeOverlay:SetFrameStrata(TradeFrame:GetFrameStrata())
  tradeOverlay:SetFrameLevel(TradeFrame:GetFrameLevel() + 100)
  tradeOverlay:EnableMouse(true)
  tradeOverlay:EnableMouseWheel(true)
  tradeOverlay:Hide()
  local bg = tradeOverlay:CreateTexture(nil, 'ARTWORK')
  bg:SetAllPoints(tradeOverlay)
  bg:SetColorTexture(0, 0, 0, 0.4)
  local text = tradeOverlay:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLarge')
  text:SetPoint('CENTER')
  text:SetText('Validating Group Found and Status...')
  tradeOverlay.text = text
  return tradeOverlay
end

local currentTradeValidation = nil

local function PrintRestrictionMessage(message)
  if not message then return end
  print('|cffff0000[Ultra Found]|r|cffffff00 ' .. message .. '|r')
end

local function ResetTradeValidation()
  currentTradeValidation = nil
  if tradeOverlay then
    tradeOverlay:Hide()
  end
end

local function CancelTradeForReason(message)
  if currentTradeValidation and currentTradeValidation.cancelled then return end
  if message then
    PrintRestrictionMessage(message)
    SendChatMessage(message, 'EMOTE')
  end
  CancelTrade()
  if currentTradeValidation then
    currentTradeValidation.cancelled = true
  end
  ResetTradeValidation()
end

local frame = CreateFrame('Frame')
frame:RegisterEvent('TRADE_SHOW')
frame:RegisterEvent('TRADE_CLOSED')
frame:RegisterEvent('AUCTION_HOUSE_SHOW')
frame:RegisterEvent('MAIL_INBOX_UPDATE')

frame:SetScript('OnEvent', function(self, event, ...)
  local inGroupFound = GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupSelfFound
  if not inGroupFound then return end

  if event == 'MAIL_INBOX_UPDATE' then
    for i = GetInboxNumItems(), 1, -1 do
      local _, _, sender, _, _, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(i)
      if sender and not isGM then
        local allowed = IsAllowedByGroupList(sender)
        if not allowed then
          local reason = 'not on my Group Found list'
          print(
            '|cffff0000[Ultra Found]|r|cffffff00 Mail from ' .. sender .. ' blocked - ' .. reason .. '.|r'
          )
          ReturnInboxItem(i)
        end
      end
    end
  elseif event == 'TRADE_SHOW' then
    -- Show overlay while we validate the trade target against the Group Found list
    currentTradeValidation = { cancelled = false }
    local overlay = EnsureTradeOverlay()
    if overlay and overlay.text then
      overlay.text:SetText('Validating Group Found restrictions...')
      overlay:Show()
    end

    local targetName = GetUnitName('npc', true)
    if not targetName then
      ResetTradeValidation()
      return
    end
    if inGroupFound then
      if not IsAllowedByGroupList(targetName) then
        CancelTradeForReason(
          'Trade with ' .. targetName .. ' cancelled - not on my Group Found list.'
        )
        return
      end
    end

    -- Target is allowed; hide the overlay so the player can trade normally
    ResetTradeValidation()
  elseif event == 'AUCTION_HOUSE_SHOW' then
    print(
      '|cffff0000[Ultra Found]|r|cffffff00 Auction House blocked - Group Found mode enabled.|r'
    )
    if C_Timer and C_Timer.After then
      C_Timer.After(0.1, function()
        if CloseAuctionHouse then
          CloseAuctionHouse()
        end
      end)
    end
  elseif event == 'TRADE_CLOSED' then
    ResetTradeValidation()
  end
end)
