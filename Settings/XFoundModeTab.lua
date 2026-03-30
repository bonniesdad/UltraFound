local TEXTURE_PATH = 'Interface\\AddOns\\UltraFound\\Textures'

-- Local state for input fields so we can enable/disable them after confirmation
local groupInputs = {}
local confirmButton
local addPartyButton
local statusText
-- All form elements to hide when switching to summary (so we don't rely on GetChildren)
local formElements = {}

local function IsGroupLocked()
  return ULTRA_FOUND_GLOBAL_SETTINGS and ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundLocked
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
  local names = (ULTRA_FOUND_GLOBAL_SETTINGS and ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundNames) or {}
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
  if not ULTRA_FOUND_GLOBAL_SETTINGS then
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

  ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundNames = names
  ULTRA_FOUND_GLOBAL_SETTINGS.guildSelfFound = false
  ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundLocked = true

  if UltraFound_SaveCharacterSettings then
    UltraFound_SaveCharacterSettings(ULTRA_FOUND_GLOBAL_SETTINGS)
  end

  print(
    '|cff00ff00[Ultra Found]|r Group Found confirmed. Trading and mail will be restricted to your Group Found list.'
  )

  SetInputsEnabled(false)

  -- Switch the tab to the summary view immediately (no reload needed)
  if confirmButton and UltraFound_CreateGroupFoundSummary then
    local content = confirmButton:GetParent()
    if content then
      for _, el in ipairs(formElements) do
        if el and el.ClearAllPoints and el.SetParent and el.Hide then
          el:ClearAllPoints()
          el:SetParent(nil)
          el:Hide()
        end
      end
      formElements = {}
      UltraFound_CreateGroupFoundSummary(content)
    end
  end
end

-- Clears all team members and returns to the setup form. Called after "Remove All" confirmation.
function UltraFound_ResetToGroupFoundSetup(content)
  if not content then return end
  if not ULTRA_FOUND_GLOBAL_SETTINGS then return end

  ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundNames = {}
  ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundLocked = false
  if ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundRoles then
    ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundRoles = {}
  end
  if ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundOffSpecRoles then
    ULTRA_FOUND_GLOBAL_SETTINGS.groupFoundOffSpecRoles = {}
  end
  if UltraFound_SaveCharacterSettings then
    UltraFound_SaveCharacterSettings(ULTRA_FOUND_GLOBAL_SETTINGS)
  end

  -- Clear summary children
  local children = { content:GetChildren() }
  for i = #children, 1, -1 do
    local child = children[i]
    if child and child.ClearAllPoints then
      child:ClearAllPoints()
      child:SetParent(nil)
      child:Hide()
    end
  end

  -- Force full tab re-init so the setup form renders correctly (avoids blank screen)
  if UltraFound_ForceRefreshXFoundModeTab then
    UltraFound_ForceRefreshXFoundModeTab()
  else
    groupInputs = {}
    formElements = {}
    CreateGroupFoundSetupForm(content)
    content:Show()
  end
end

local function CreateGroupFoundSetupForm(content)
  local title = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  title:SetPoint('TOP', content, 'TOP', 0, -60)
  title:SetText('Group Found Setup')
  title:SetTextColor(0.922, 0.871, 0.761)
  table.insert(formElements, title)

  local description = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  description:SetPoint('TOP', title, 'BOTTOM', 0, -10)
  description:SetWidth(380)
  description:SetJustifyH('CENTER')
  description:SetText(
    'Choose the characters you will adventure with on this run.\n\n' ..
    'Trading and mail will be restricted to the names you confirm below.\n\n' ..
    'Once confirmed, this list cannot be changed on this character.'
  )
  description:SetTextColor(0.9, 0.9, 0.9)
  table.insert(formElements, description)

  local NUM_FIELDS = 4
  local fieldGap = 32
  local startYOffset = -40

  for i = 1, NUM_FIELDS do
    local label = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    label:SetPoint('TOP', description, 'BOTTOM', -120, startYOffset - (i - 1) * fieldGap)
    label:SetText('Character ' .. i .. ':')
    label:SetTextColor(0.8, 0.8, 0.8)
    table.insert(formElements, label)

    local box = CreateFrame('EditBox', nil, content, 'InputBoxTemplate')
    box:SetSize(220, 24)
    box:SetAutoFocus(false)
    box:SetPoint('LEFT', label, 'RIGHT', 10, 0)
    box:SetMaxLetters(64)
    box:SetText('')
    table.insert(formElements, box)
    table.insert(groupInputs, box)
  end

  local lastBox = groupInputs[NUM_FIELDS]

  statusText = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  statusText:SetPoint('TOP', lastBox, 'BOTTOM', -36, -18)
  statusText:SetWidth(380)
  statusText:SetJustifyH('CENTER')
  statusText:SetTextColor(0.7, 0.9, 0.7)
  statusText:SetText('You can edit this list until you press Confirm Group.')
  table.insert(formElements, statusText)

  addPartyButton = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
  addPartyButton:SetSize(140, 22)
  addPartyButton:SetPoint('TOP', statusText, 'BOTTOM', 0, -10)
  addPartyButton:SetText('Add Party Members')
  addPartyButton:SetScript('OnClick', PopulateFromParty)
  table.insert(formElements, addPartyButton)

  confirmButton = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
  confirmButton:SetSize(160, 24)
  confirmButton:SetPoint('BOTTOM', content, 'BOTTOM', 0, 0)
  confirmButton:SetText('Confirm Group')
  confirmButton:SetScript('OnClick', ConfirmGroup)
  table.insert(formElements, confirmButton)

  SetInputsEnabled(true)
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

  CreateGroupFoundSetupForm(content)
  LoadExistingGroupIntoInputs()
end
