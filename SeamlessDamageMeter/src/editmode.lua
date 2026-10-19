---@type string, SeamlessDamageMeter
local _, app = ...

local lib = LibStub("LibEditMode")
local showUsedWindows = true
local registered = {}
local groupCheckbox

local function RegisterGroupCheckbox()
    if groupCheckbox then
        return
    end
    local parent = EditModeManagerFrame.AccountSettings.SettingsContainer.ScrollChild.AdvancedOptionsContainer
    local row = CreateFrame("Frame", nil, parent, "ResizeCheckButtonTemplate")
    row.layoutIndex = 1000
    row.fixedWidth, row.fixedHeight = 225, 32
    row:SetSize(225, 32)
    row.Label:SetText("Seamless Damage Meter")
    row.Label:SetFontObject(GameFontHighlightMedium)
    parent:MarkDirty()
    groupCheckbox = row.Button
    groupCheckbox:SetChecked(showUsedWindows)
    groupCheckbox:SetScript("OnClick", function(button)
        if app:IsEditingWindows() and not InCombatLockdown() then
            showUsedWindows = button:GetChecked()
            EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
            app:RebuildWindows()
        else
            button:SetChecked(showUsedWindows)
        end
    end)
end

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

local function RegisterControls(frame)
    local settings = {}
    local function add(name, key, kind, minimum, maximum, step, multiplier, skin)
        multiplier = multiplier or 1
        local function get()
            local value = app:GetWindowSetting(frame.config, key)
            if key == "backgroundColor" then
                value = value[4]
            end
            return kind == lib.SettingType.Slider and SliderValue(value * multiplier, step) or value
        end
        settings[#settings + 1] = {
            name = name,
            kind = kind,
            default = get(),
            get = get,
            minValue = minimum,
            maxValue = maximum,
            valueStep = step,
            formatter = function(value)
                return tostring(value)
            end,
            disabled = function()
                return (key == "width" or key == "height")
                    and (
                        app:GetWindowSetting(frame.config, "lockSize")
                        or (key == "height" and app:GetWindowSetting(frame.config, "fixedHeight"))
                    )
            end,
            set = function(_, value)
                if skin then
                    SetSkinOption(
                        frame,
                        key,
                        kind == lib.SettingType.Slider and SliderValue(value, step) / multiplier or value
                    )
                elseif key == "width" or key == "height" then
                    ResizeWindow(frame, key, value)
                else
                    SetWindowOption(
                        frame,
                        key,
                        kind == lib.SettingType.Slider and SliderValue(value, step) / multiplier or value
                    )
                end
            end,
        }
    end
    add("Frame scale", "scale", lib.SettingType.Slider, 50, 200, 5, 100)
    add("Frame width", "width", lib.SettingType.Slider, 200, 800, 1)
    add("Frame height", "height", lib.SettingType.Slider, 120, 900, 1)
    add("Fixed height by row count", "fixedHeight", lib.SettingType.Checkbox)
    add("Row count", "visibleLines", lib.SettingType.Slider, 1, 30, 1)
    add("Lock size", "lockSize", lib.SettingType.Checkbox)
    add("Lock position", "lockPosition", lib.SettingType.Checkbox)
    for _, definition in ipairs(appearanceSliders) do
        add(
            definition[1],
            definition[2],
            lib.SettingType.Slider,
            definition[3],
            definition[4],
            definition[5],
            definition[6],
            true
        )
    end
    for _, definition in ipairs(appearanceChecks) do
        add(definition[1], definition[2], lib.SettingType.Checkbox, nil, nil, nil, nil, true)
    end
    settings[#settings + 1] = {
        name = "Skin",
        kind = lib.SettingType.Dropdown,
        default = "default",
        get = function()
            return frame.config.skin
        end,
        set = function(_, value)
            if app:IsEditingWindows() and not InCombatLockdown() then
                frame.config.skin = value
                app:RebuildWindows()
            end
        end,
        values = function()
            local keys, values = {}, {}
            for key in pairs(app.db.profile.skins) do
                if key ~= "default" then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys)
            table.insert(keys, 1, "default")
            for _, key in ipairs(keys) do
                values[#values + 1] = { text = app.db.profile.skins[key].name, value = key }
            end
            return values
        end,
    }
    lib:AddFrameSettings(frame, settings)
    lib:AddFrameSettingsButtons(frame, {
        {
            text = "Edit selected skin",
            click = function()
                if not InCombatLockdown() then
                    app.core:OpenOptions("SeamlessDamageMeter", "skin")
                    LibStub("AceConfigDialog-3.0"):SelectGroup("SeamlessDamageMeter", "skin", frame.config.skin)
                end
            end,
        },
        {
            text = "Create new window",
            click = function()
                if app:IsEditingWindows() and not InCombatLockdown() then
                    app:AddWindow()
                end
            end,
        },
        {
            text = "Remove window",
            click = function()
                if app:IsEditingWindows() and not InCombatLockdown() then
                    EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                    app:SetWindowEnabled(frame.config, false)
                end
            end,
        },
    })
end

function app:IsEditingWindows()
    return lib:IsInEditMode()
end

function app:SyncWindowEditMode(frame)
    if InCombatLockdown() or not EditModeManagerFrame then
        return
    end
    frame.syncingEditMode = true
    local rebound = type(registered[frame]) == "table" and registered[frame] ~= frame.config
    if not registered[frame] then
        registered[frame] = true
        lib:AddFrame(frame, function()
            if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
                return
            end
            if not app:GetWindowSetting(frame.config, "lockPosition") then
                app:SaveWindowPosition(frame, true)
            end
            -- Convert the library's screen anchor back to our independent linked anchors.
            app:PositionWindow(frame)
            app.core:RefreshOptions("SeamlessDamageMeter")
        end, { point = "CENTER", x = 0, y = 0 }, "Seamless Damage " .. frame.windowID)
        RegisterControls(frame)
        local selection = frame.Selection
        local dragStart = selection:GetScript("OnDragStart")
        selection:SetScript("OnDragStart", function(self, ...)
            if not app:GetWindowSetting(frame.config, "lockPosition") then
                dragStart(self, ...)
            end
        end)
        RegisterGroupCheckbox()
    end
    frame:SetScale(self:GetWindowSetting(frame.config, "scale"))
    self:PositionWindow(frame)
    local editing = self:IsEditingWindows()
    frame.Selection:SetShown(editing and showUsedWindows and frame.config.enabled)
    frame.resize:SetFrameStrata(editing and "HIGH" or frame:GetFrameStrata())
    frame.resize:SetFrameLevel(frame.Selection:GetFrameLevel() + 1)
    frame.resize:EnableMouse(not self:GetWindowSetting(frame.config, "lockSize"))
    if editing then
        frame.resize:SetAlpha(1)
    else
        frame:SetMovable(true)
    end
    frame.syncingEditMode = nil
    registered[frame] = frame.config
    if rebound then
        lib:RefreshFrameSettings(frame)
    end
end

function app:WindowShouldBeShown(frame)
    if self:IsEditingWindows() then
        return showUsedWindows and frame.config.enabled
    end
    return self.addon:IsEnabled() and frame.config.enabled and not frame.config.hidden
end

local function RefreshEditMode()
    if app.db and not InCombatLockdown() then
        app:RebuildWindows()
    end
end
lib:RegisterCallback("enter", RefreshEditMode)
lib:RegisterCallback("exit", RefreshEditMode)
lib:RegisterCallback("layout", RefreshEditMode)
