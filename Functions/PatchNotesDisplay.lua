-- Addon-scoped so Ultra Hardcore's CreatePatchNotesDisplay cannot be used here
function UltraFound_CreatePatchNotesDisplay(parent, width, height, xOffset, yOffset)
  local patchNotesScrollFrame =
    CreateFrame('ScrollFrame', nil, parent, 'UIPanelScrollFrameTemplate')
  patchNotesScrollFrame:SetSize(width, height)
  patchNotesScrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', xOffset, yOffset)

  local patchNotesScrollChild = CreateFrame('Frame', nil, patchNotesScrollFrame)
  patchNotesScrollChild:SetSize(width, height)
  patchNotesScrollFrame:SetScrollChild(patchNotesScrollChild)

  local function createBulletText(parent, text, yOffset, fontSize, textColor)
    local indent = 10
    local textWidth = width - indent
    local textFrame = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    textFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', indent, yOffset)
    textFrame:SetWidth(textWidth)
    textFrame:SetJustifyH('LEFT')
    local font, _, flags = textFrame:GetFont()
    textFrame:SetFont(font, fontSize or 13, flags)
    textFrame:SetTextColor(textColor[1], textColor[2], textColor[3])
    textFrame:SetText(text)
    return textFrame
  end

  -- Use _G to ensure we read our addon's table at display time (not overwritten by load order)
  local notes = (_G.UltraFound_PATCH_NOTES and type(_G.UltraFound_PATCH_NOTES) == 'table') and _G.UltraFound_PATCH_NOTES or {}
  local yOffset = 0
  for i, patch in ipairs(notes) do
    -- Only skip if patch has an explicit expansion that doesn't match; no expansion = show everywhere
    local shouldSkip = false
    if patch.expansion then
      if patch.expansion == 'TBC' and IsTBC and not IsTBC() then
        shouldSkip = true
      elseif patch.expansion == 'Classic' and IsTBC and IsTBC() then
        shouldSkip = true
      end
    end
    if not shouldSkip then
      local versionHeader =
        patchNotesScrollChild:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
      versionHeader:SetPoint('TOPLEFT', patchNotesScrollChild, 'TOPLEFT', 0, yOffset)
      versionHeader:SetWidth(width)
      versionHeader:SetJustifyH('LEFT')
      local font, _, flags = versionHeader:GetFont()
      versionHeader:SetFont(font, 14, flags)
      versionHeader:SetTextColor(1, 1, 0)
      versionHeader:SetText('Version ' .. patch.version .. ' (' .. patch.date .. ')')
      local headerHeight = versionHeader:GetStringHeight()
      yOffset = yOffset - headerHeight - 12
      for j, note in ipairs(patch.notes) do
        local noteText =
          createBulletText(patchNotesScrollChild, note, yOffset, 13, { 0.9, 0.9, 0.9 })
        local noteHeight = noteText:GetStringHeight()
        yOffset = yOffset - noteHeight - 3
      end
      yOffset = yOffset - 12
    end
  end
  if yOffset == 0 then
    local emptyLabel = patchNotesScrollChild:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    emptyLabel:SetPoint('TOPLEFT', patchNotesScrollChild, 'TOPLEFT', 10, 0)
    emptyLabel:SetWidth(width - 20)
    emptyLabel:SetText('No patch notes to display.')
    emptyLabel:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - emptyLabel:GetStringHeight() - 12
  end
  patchNotesScrollChild:SetHeight(math.max(height, math.abs(yOffset) + 20))
  return patchNotesScrollFrame
end
