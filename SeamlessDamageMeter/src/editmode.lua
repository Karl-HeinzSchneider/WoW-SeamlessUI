---@type string, SeamlessDamageMeter
local _, app = ...

local lib = LibStub("EditModeExpanded-1.0")
local groupCheckbox
local showUsedWindows = true

local function RegisterGroupCheckbox(frame)
    local row = frame.EMECheckButtonFrame:GetParent()
    if not groupCheckbox then
        local scrollChild = row:GetParent()
        local groupRow = CreateFrame("Frame", nil, scrollChild, "ResizeCheckButtonTemplate")
        groupRow.layoutIndex = row.layoutIndex
        groupRow.fixedWidth, groupRow.fixedHeight = 225, 32
        groupRow.Label:SetText("Seamless Damage Meter")
        groupRow.Label:SetFontObject(GameFontHighlightMedium)
        groupCheckbox = groupRow.Button
        groupCheckbox:SetChecked(showUsedWindows)
        groupCheckbox:SetScript("OnClick", function(button)
            if app:IsEditingWindows() and not InCombatLockdown() then
                showUsedWindows = button:GetChecked()
                app:RebuildWindows()
            else
                button:SetChecked(showUsedWindows)
            end
        end)
    end
    row:Hide()
end
local SCALE_SETTING = 16 -- EditModeExpanded's FrameSize setting.
local CHECKBOX_SETTING = 12 -- EditModeExpanded custom checkboxes.
local SLIDER_SETTING = 18 -- EditModeExpanded's custom sliders.

-- Only slider values are quantized; stored geometry can retain intentional fractions.
local function SliderValue(value, step)
    return math.floor(value / step + 0.5) * step
end

local function ResizeWindow(frame, key, value)
    if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
        return
    end
    if app:GetWindowSetting(frame.config, "lockSize") then
        app:SyncWindowEditMode(frame)
        return
    end
    if key == "height" and app:GetWindowSetting(frame.config, "fixedHeight") then
        app:SyncWindowEditMode(frame)
        return
    end
    value = SliderValue(value, 1)
    if value == app:GetWindowSetting(frame.config, key) then
        return
    end
    frame.config.overrides[key] = value
    frame.applyingLayout = true
    frame:SetSize(app:GetWindowSetting(frame.config, "width"), app:GetWindowSetting(frame.config, "height"))
    frame.applyingLayout = nil
    app:ApplyWindowLayout(frame)
    app:RefreshWindows()
    app.core:RefreshOptions("SeamlessDamageMeter")
end

local function SetWindowOption(frame, key, value)
    if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
        return
    end
    if app:GetWindowSetting(frame.config, key) == value then
        return
    end
    frame.config.overrides[key] = value
    app:RebuildWindows()
end

-- Appearance edits intentionally update the selected shared skin.
local appearanceSliders = {
    { "Bar height", "rowHeight", 16, 40, 1 },
    { "Padding", "rowSpacing", 0, 12, 1 },
    { "Transparency", "windowAlpha", 50, 100, 1, 100 },
    { "Background", "backgroundColor", 0, 100, 1, 100 },
    { "Text size", "fontSize", 50, 150, 10, 100 / 15 },
}
local appearanceChecks = {
    { "Show spec icon", "showIcons" },
    { "Show class color", "classColors" },
}

local function SetSkinOption(frame, key, value)
    if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
        return
    end
    local settings = app.db.profile.skins[frame.config.skin].settings
    if key == "backgroundColor" then
        local color = app:GetWindowSetting(frame.config, key)
        settings[key] = { color[1], color[2], color[3], value }
    else
        settings[key] = value
    end
    app:RebuildWindows()
end

local function RegisterAppearanceControls(frame)
    for _, definition in ipairs(appearanceSliders) do
        local key, divisor = definition[2], definition[6] or 1
        lib:RegisterSlider(frame, definition[1], key, function(value)
            SetSkinOption(frame, key, SliderValue(value, definition[5]) / divisor)
        end, definition[3], definition[4], definition[5])
    end
    for _, definition in ipairs(appearanceChecks) do
        local key = definition[2]
        lib:RegisterCustomCheckbox(frame, definition[1], function()
            SetSkinOption(frame, key, true)
        end, function(initializing)
            if not initializing then
                SetSkinOption(frame, key, false)
            end
        end, key)
    end
end

-- EME's dropdown slot accepts a factory; use our own menu button rather than
-- introducing a second dropdown library solely for this selector.
local dropdownFactory = {}
function dropdownFactory:Create_UIDropDownMenu(_, parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(250, 28)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontNormalSmall")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-dropdown-c-button")
    background:SetAllPoints()
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
    arrow:SetPoint("RIGHT", -8, 0)
    return button
end

local function RegisterSkinControls(frame)
    local dropdown = lib:RegisterDropdown(frame, dropdownFactory, "skin")
    frame.skinDropdown = dropdown
    dropdown:SetScript("OnClick", function(button)
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateTitle("Skin")
            local keys = {}
            for key in pairs(app.db.profile.skins) do
                if key ~= "default" then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys)
            table.insert(keys, 1, "default")
            for _, key in ipairs(keys) do
                root:CreateRadio(app.db.profile.skins[key].name, function()
                    return frame.config.skin == key
                end, function()
                    if app:IsEditingWindows() and not InCombatLockdown() then
                        frame.config.skin = key
                        app:RebuildWindows()
                    end
                end)
            end
        end)
    end)
    lib:RegisterCustomButton(frame, "Edit selected skin", function()
        if not InCombatLockdown() then
            app.core:OpenOptions("SeamlessDamageMeter", "skin")
            LibStub("AceConfigDialog-3.0"):SelectGroup("SeamlessDamageMeter", "skin", frame.config.skin)
        end
    end, "editSkin")
end

function app:IsEditingWindows()
    return EditModeManagerFrame and EditModeManagerFrame.editModeActive
end

local function CurrentLayout(db)
    local layout = EditModeManagerFrame:GetActiveLayoutInfo()
    if not layout then
        return db
    end
    local key = layout.layoutType .. "-" .. layout.layoutName
    if layout.layoutType == Enum.EditModeLayoutType.Character then
        local name, realm = UnitFullName("player")
        if name and realm then
            key = layout.layoutType .. "-" .. name .. "-" .. realm .. "-" .. layout.layoutName
        end
    end
    db.profiles = db.profiles or {}
    db.profiles[key] = db.profiles[key] or { settings = {} }
    return db.profiles[key]
end

function app:SyncWindowEditMode(frame)
    if InCombatLockdown() or not EditModeManagerFrame then
        return
    end
    frame.syncingEditMode = true
    local config = frame.config
    config.editMode = config.editMode or { settings = {} }
    if not lib:IsRegistered(frame) then
        lib:RegisterFrame(frame, "Seamless Damage " .. frame.windowID, config.editMode)
        RegisterGroupCheckbox(frame)
        -- Guard both native selection dragging and EME's independent arrow-key path.
        local canBeMoved = frame.CanBeMoved
        frame.CanBeMoved = function(self)
            return not app:GetWindowSetting(self.config, "lockPosition") and canBeMoved(self)
        end
        local moveWithArrowKey = frame.MoveWithArrowKey
        frame.MoveWithArrowKey = function(self, key)
            if not app:GetWindowSetting(self.config, "lockPosition") then
                moveWithArrowKey(self, key)
            end
        end
        lib:RegisterResizable(frame, 50, 200, 5)
        lib:RegisterSlider(frame, "Frame width", "width", function(value)
            ResizeWindow(frame, "width", value)
        end, 200, 800, 1)
        lib:RegisterSlider(frame, "Frame height", "height", function(value)
            ResizeWindow(frame, "height", value)
        end, 120, 900, 1)
        lib:RegisterCustomCheckbox(frame, "Fixed height by row count", function()
            SetWindowOption(frame, "fixedHeight", true)
        end, function(initializing)
            if not initializing then
                SetWindowOption(frame, "fixedHeight", false)
            end
        end, "fixedHeight")
        lib:RegisterSlider(frame, "Row count", "visibleLines", function(value)
            SetWindowOption(frame, "visibleLines", SliderValue(value, 1))
        end, 1, 30, 1)
        lib:RegisterCustomCheckbox(frame, "Lock size", function()
            SetWindowOption(frame, "lockSize", true)
        end, function(initializing)
            if not initializing then
                SetWindowOption(frame, "lockSize", false)
            end
        end, "lockSize")
        lib:RegisterCustomCheckbox(frame, "Lock position", function()
            SetWindowOption(frame, "lockPosition", true)
        end, function(initializing)
            if not initializing then
                SetWindowOption(frame, "lockPosition", false)
            end
        end, "lockPosition")
        RegisterAppearanceControls(frame)
        RegisterSkinControls(frame)
        lib:RegisterCustomButton(frame, "Create new window", function()
            if app:IsEditingWindows() and not InCombatLockdown() then
                app:AddWindow()
            end
        end, "createWindow")
        lib:SetDontResize(frame) -- Keep collapsed headers at their actual height.
        hooksecurefunc(frame, "SetPoint", function()
            if
                frame.config
                and not InCombatLockdown()
                and not frame.positioning
                and not frame.syncingEditMode
                and not frame.applyingLayout
            then
                app:SaveWindowPosition(frame, true)
                app.core:RefreshOptions("SeamlessDamageMeter")
            end
        end)
        hooksecurefunc(frame, "SetScaleOverride", function(_, newScale)
            if frame.config and not InCombatLockdown() and not frame.syncingEditMode then
                local configured = app:GetWindowSetting(frame.config, "scale")
                local scale = configured
                if math.abs(newScale - configured) > 0.000001 then
                    scale = app:IsEditingWindows() and SliderValue(newScale * 100, 5) / 100 or newScale
                    frame.config.overrides.scale = scale
                end
                local db = lib.framesDB[frame.system]
                db.settings[SCALE_SETTING] = SliderValue(scale * 100, 5)
                app:SaveWindowPosition(frame, true)
                app.core:RefreshOptions("SeamlessDamageMeter")
            end
        end)
        if not app.editModeHooked then
            app.editModeHooked = true
            hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
                if not InCombatLockdown() then
                    app:RebuildWindows()
                end
            end)
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
                if not InCombatLockdown() then
                    app:RebuildWindows()
                end
            end)
        end
    end
    -- RegisterFrame does not rebind an already registered frame. These exposed library
    -- tables (EME minor 121) let pooled frames follow AceDB profile switches/resets.
    lib.baseFramesDB[frame.system] = config.editMode
    frame:SetScale(self:GetWindowSetting(config, "scale"))
    self:PositionWindow(frame)
    local db = CurrentLayout(config.editMode)
    lib.framesDB[frame.system] = db
    -- Preview visibility is separate from real slot activation and temporary hiding.
    local previewEnabled = config.enabled and showUsedWindows
    for _, layout in pairs(config.editMode.profiles or {}) do
        layout.enabled = previewEnabled
    end
    db.enabled = previewEnabled
    config.editMode.windowEnabled = nil
    config.editMode.enabled = previewEnabled
    frame.EMEdisabledByDefault = not previewEnabled
    db.settings = db.settings or {}
    db.x, db.y = frame:GetRect()
    db.defaultX, db.defaultY = db.x, db.y
    db.defaultScale = frame:GetScale()
    db.settings[SCALE_SETTING] = SliderValue(self:GetWindowSetting(config, "scale") * 100, 5)
    db.settings[SLIDER_SETTING] = db.settings[SLIDER_SETTING] or {}
    db.settings[SLIDER_SETTING].width = SliderValue(self:GetWindowSetting(config, "width"), 1)
    db.settings[SLIDER_SETTING].height = SliderValue(self:GetWindowSetting(config, "height"), 1)
    db.settings[SLIDER_SETTING].visibleLines = SliderValue(self:GetWindowSetting(config, "visibleLines"), 1)
    db.settings[CHECKBOX_SETTING] = db.settings[CHECKBOX_SETTING] or {}
    db.settings[CHECKBOX_SETTING].fixedHeight = self:GetWindowSetting(config, "fixedHeight") and 1 or 0
    db.settings[CHECKBOX_SETTING].lockSize = self:GetWindowSetting(config, "lockSize") and 1 or 0
    db.settings[CHECKBOX_SETTING].lockPosition = self:GetWindowSetting(config, "lockPosition") and 1 or 0
    for _, definition in ipairs(appearanceSliders) do
        local key, multiplier = definition[2], definition[6] or 1
        local value = self:GetWindowSetting(config, key)
        if key == "backgroundColor" then
            value = value[4]
        end
        db.settings[SLIDER_SETTING][key] = SliderValue(value * multiplier, definition[5])
    end
    for _, definition in ipairs(appearanceChecks) do
        local key = definition[2]
        db.settings[CHECKBOX_SETTING][key] = self:GetWindowSetting(config, key) and 1 or 0
    end
    frame.skinDropdown:SetText("Skin: " .. self.db.profile.skins[config.skin].name)
    if db.enabled == nil then
        db.enabled = config.enabled
    end
    if db.clamped == nil then
        db.clamped = 1
    end
    frame.EMECheckButtonFrame:SetChecked(db.enabled)
    -- EME moves with matching anchor points; retain our independent anchor points by
    -- converting its resulting screen position back to the meter's X/Y overrides.
    frame.EMEanchorTo, frame.EMEanchorPoint = frame.anchorTarget or UIParent, "BOTTOMLEFT"
    -- The selection is a top-level frame and may be raised after registration.
    -- Give the grip its own strata in Edit Mode so the selection cannot cover it.
    frame.resize:SetFrameStrata(self:IsEditingWindows() and "HIGH" or frame:GetFrameStrata())
    frame.resize:SetFrameLevel(frame.Selection:GetFrameLevel() + 1)
    frame.resize:EnableMouse(not self:GetWindowSetting(config, "lockSize"))
    if self:IsEditingWindows() then
        frame.resize:SetAlpha(1)
    end
    local dialog = EditModeExpandedSystemSettingsDialog
    if self:IsEditingWindows() and dialog and dialog.attachedToSystem == frame then
        local dragging = false
        for slider in dialog.pools:EnumerateActiveByTemplate("EditModeSettingSliderTemplate") do
            if slider.Slider.Slider:IsDraggingThumb() then
                dragging = true
                break
            end
        end
        -- EME identifies its retained dragging slider by setting ID only; all
        -- custom sliders share 18, so rebuilding the dialog mid-drag aliases them.
        if not dragging then
            dialog:UpdateSettings(frame)
        end
    end
    frame.syncingEditMode = nil
    if not self:IsEditingWindows() then
        frame:SetMovable(true)
    end
end

function app:WindowShouldBeShown(frame)
    if self:IsEditingWindows() and lib:IsRegistered(frame) then
        return showUsedWindows and frame.config.enabled and lib:IsFrameEnabled(frame)
    end
    return self.addon:IsEnabled() and frame.config.enabled and not frame.config.hidden
end
