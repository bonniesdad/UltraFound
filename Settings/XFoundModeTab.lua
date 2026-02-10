local TEXTURE_PATH = 'Interface\\AddOns\\UltraFound\\Textures'

-- Local state for input fields so we can enable/disable them after confirmation
local groupInputs = {}
local confirmButton
local addPartyButton
local statusText

local function IsGroupLocked()
  return GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundLocked
end

local function SetInputsEnabled(enabled)
  for _, box in ipairs(groupInputs) do
    if enabled then
      box:Enable()
    else
      box:Disable()
    end
  end
  if confirmButton then
    if enabled then
      confirmButton:Enable()
    else
      confirmButton:Disable()
    end
  end
  if addPartyButton then
    if enabled then
      addPartyButton:Enable()
    else
      addPartyButton:Disable()
    end
  end
end

local function LoadExistingGroupIntoInputs()
  local names = (GLOBAL_SETTINGS and GLOBAL_SETTINGS.groupFoundNames) or {}
  for i, box in ipairs(groupInputs) do
    box:SetText(names[i] or '')
  end
end

local function PopulateFromParty()
  if IsGroupLocked() then return end

  local collected = {}

  -- Collect party members (your own character is implicitly part of the group
  -- and does not need its own input field)
  for i = 1, 4 do
    local unit = 'party' .. i
    local name = UnitName and UnitName(unit)
    if name and name ~= '' then
      table.insert(collected, name)
    end
  end

  if #collected == 0 then
    print('|cffffd000[Ultra Found]|r No party members found to add.')
    return
  end

  for i, box in ipairs(groupInputs) do
    box:SetText(collected[i] or '')
  end
end

local function ConfirmGroup()
  if not GLOBAL_SETTINGS then
    print('|cffffd000[Ultra Found]|r Settings not loaded. Try again in a moment.')
    return
  end

  if IsGroupLocked() then
    print('|cffffd000[Ultra Found]|r Group Found is already locked for this character.')
    return
  end

  local names = {}
  for _, box in ipairs(groupInputs) do
    local text = box:GetText() or ''
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text ~= '' then
      table.insert(names, text)
    end
  end

  if #names == 0 then
    print('|cffffd000[Ultra Found]|r Please enter at least one character name before confirming the group.')
    return
  end

  GLOBAL_SETTINGS.groupFoundNames = names
  GLOBAL_SETTINGS.groupSelfFound = true
  GLOBAL_SETTINGS.guildSelfFound = false
  GLOBAL_SETTINGS.groupFoundLocked = true

  if SaveCharacterSettings then
    SaveCharacterSettings(GLOBAL_SETTINGS)
  end

  print(
    '|cff00ff00[Ultra Found]|r Group Found confirmed. Trading and mail will be restricted to your Group Found list.'
  )

  if statusText then
    statusText:SetText('Group Found is locked for this character.\nThese names cannot be changed.')
    statusText:SetTextColor(0.9, 0.7, 0.2)
  end

  SetInputsEnabled(false)
end

function UltraFound_InitializeXFoundModeTab(tabContents)
  if not tabContents or not tabContents[1] then return end
  if tabContents[1].initialized then return end
  tabContents[1].initialized = true

  local content = tabContents[1]

  -- If the group is already locked for this character, show the
  -- summary/overview layout instead of the setup form.
  if IsGroupLocked() and UltraFound_CreateGroupFoundSummary then
    UltraFound_CreateGroupFoundSummary(content)
    return
  end

  local title = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  title:SetPoint('TOP', content, 'TOP', 0, -60)
  title:SetText('Group Found Setup')
  title:SetTextColor(0.922, 0.871, 0.761)

  local description = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  -- Slightly offset left so it visually centers with the form below
  description:SetPoint('TOP', title, 'BOTTOM', 0, -10)
  description:SetWidth(380)
  description:SetJustifyH('CENTER')
  description:SetText(
    'Choose the characters you will adventure with on this run.\n\n' ..
    'Trading and mail will be restricted to the names you confirm below.\n' ..
    'Once confirmed, this list cannot be changed on this character.'
  )
  description:SetTextColor(0.9, 0.9, 0.9)

  -- Create input boxes, positioned relative to the description text
  -- so the whole form sits cleanly below the copy.
  -- We only need fields for your group-mates.
  -- Your own character is always implicitly part of the group, so we keep 4 inputs.
  local NUM_FIELDS = 4
  local fieldGap = 32
  local startYOffset = -40 -- distance from bottom of description to first row

  for i = 1, NUM_FIELDS do
    local label = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    -- Anchor labels relative to the center so the whole form is visually centered
    label:SetPoint('TOP', description, 'BOTTOM', -120, startYOffset - (i - 1) * fieldGap)
    label:SetText('Character ' .. i .. ':')
    label:SetTextColor(0.8, 0.8, 0.8)

    local box = CreateFrame('EditBox', nil, content, 'InputBoxTemplate')
    box:SetSize(220, 24)
    box:SetAutoFocus(false)
    box:SetPoint('LEFT', label, 'RIGHT', 10, 0)
    box:SetMaxLetters(64)
    box:SetText('')

    table.insert(groupInputs, box)
  end

  local lastBox = groupInputs[NUM_FIELDS]

  -- Status text (lock information)
  statusText = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  statusText:SetPoint('TOP', lastBox, 'BOTTOM', -36, -18)
  statusText:SetWidth(380)
  statusText:SetJustifyH('CENTER')
  statusText:SetTextColor(0.7, 0.7, 0.7)

  -- Buttons

  addPartyButton =
    CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
  addPartyButton:SetSize(140, 22)
  -- Centered horizontally just under the status text (lock/info text),
  -- nudged slightly left to visually align with the text block
  addPartyButton:SetPoint('TOP', statusText, 'BOTTOM', 0, -10)
  addPartyButton:SetText('Add Party Members')
  addPartyButton:SetScript('OnClick', PopulateFromParty)

  confirmButton =
    CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
  confirmButton:SetSize(160, 24)
  -- Centered horizontally near the bottom of the tab
  confirmButton:SetPoint('BOTTOM', content, 'BOTTOM', 0, 0)
  confirmButton:SetText('Confirm Group')
  confirmButton:SetScript('OnClick', ConfirmGroup)

  -- Initialize from existing data
  LoadExistingGroupIntoInputs()

  if IsGroupLocked() then
    statusText:SetText('Group Found is locked for this character.\nThese names cannot be changed.')
    statusText:SetTextColor(0.9, 0.7, 0.2)
    SetInputsEnabled(false)
  else
    statusText:SetText('You can edit this list until you press Confirm Group.')
    statusText:SetTextColor(0.7, 0.9, 0.7)
    SetInputsEnabled(true)
  end
end
