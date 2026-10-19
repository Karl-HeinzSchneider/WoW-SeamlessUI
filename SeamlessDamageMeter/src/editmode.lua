---@type string, SeamlessDamageMeter
local _, app = ...

local lib = app.core:GetEditModeLibrary()
local activeLayout
local layoutKeys = { "point", "relativePoint", "x", "y", "width", "height", "scale" }
local showUsedWindows = true
local registered = {}

-- Layout records belong to the active AceDB profile. Copy only public geometry;
-- appearance, visibility, activation and locks remain profile settings.
local function SaveLayout(config, name)
    if not name then
        return
    end
    local record = { anchorTo = config.anchorTo }
    for _, key in ipairs(layoutKeys) do
        record[key] = config.overrides[key]
    end
    config.editModeLayouts = config.editModeLayouts or {}
    config.editModeLayouts[name] = record
end

function app:ApplyEditModeLayout()
    if not activeLayout or not self.db or InCombatLockdown() then
        return
    end
    self:PrepareWindowSettings()
    for _, config in ipairs(self.db.profile.windows) do
        local record = config.editModeLayouts and config.editModeLayouts[activeLayout]
        if record then
            for _, key in ipairs(layoutKeys) do
                config.overrides[key] = record[key]
            end
            config.anchorTo = record.anchorTo
        else
            SaveLayout(config, activeLayout)
        end
    end
    for _, config in ipairs(self.db.profile.windows) do
        if config.anchorTo and not self:CanAnchorTo(config, config.anchorTo) then
            config.anchorTo = nil
        end
    end
end

app.core:RegisterEditModeOptions("SeamlessDamageMeter", {
    section = "frames",
    order = 100,
    enabled = function()
        return app.db and app.addon:IsEnabled()
    end,
    options = {
        {
            key = "windows",
            type = "toggle",
            name = "Seamless Damage Meter",
            get = function()
                return showUsedWindows
            end,
            set = function(value)
                showUsedWindows = value
                EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                app:RebuildWindows()
            end,
        },
    },
})

-- Only slider values are quantized; stored geometry can retain intentional fractions.
local function SliderValue(value, step)
    return math.floor(value / step + 0.5) * step
end

local function ResizeWindow(frame, key, value, fromReset)
    if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
        return
    end
    if not fromReset and app:GetWindowSetting(frame.config, "lockSize") then
        app:SyncWindowEditMode(frame)
        return
    end
    if not fromReset and key == "height" and app:GetWindowSetting(frame.config, "fixedHeight") then
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

-- Appearance edits target either the selected skin or this window's style overrides.
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
    if frame.config.modifyGlobalStyle == false then
        frame.config.styleOverrides = frame.config.styleOverrides or {}
        settings = frame.config.styleOverrides
    end
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
        local default = (skin and app.skinDefaults or app.windowDefaults)[key]
        if key == "backgroundColor" then
            default = default[4]
        end
        if kind == lib.SettingType.Slider then
            default = SliderValue(default * multiplier, step)
        end
        settings[#settings + 1] = {
            name = name,
            kind = kind,
            default = default,
            get = get,
            minValue = minimum,
            maxValue = maximum,
            valueStep = step,
            formatter = function(value)
                return value
            end,
            disabled = function()
                return (key == "width" or key == "height")
                    and (
                        app:GetWindowSetting(frame.config, "lockSize")
                        or (key == "height" and app:GetWindowSetting(frame.config, "fixedHeight"))
                    )
            end,
            set = function(_, value, fromReset)
                if skin then
                    SetSkinOption(
                        frame,
                        key,
                        kind == lib.SettingType.Slider and SliderValue(value, step) / multiplier or value
                    )
                elseif key == "width" or key == "height" then
                    ResizeWindow(frame, key, value, fromReset)
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
    settings[#settings + 1] = {
        name = "Numbers",
        kind = lib.SettingType.Dropdown,
        default = "complete",
        get = function()
            return app:GetWindowSetting(frame.config, "numbers")
        end,
        set = function(_, value)
            SetWindowOption(frame, "numbers", value)
        end,
        values = {
            { text = "Minimal", value = "minimal" },
            { text = "Compact", value = "compact" },
            { text = "Complete", value = "complete" },
        },
    }
    local styleStart = #settings + 1
    settings[#settings + 1] = { name = "Style", kind = lib.SettingType.Divider }
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
        name = "Show type selector",
        kind = lib.SettingType.Checkbox,
        default = not app.skinDefaults.hideTypeSelector,
        get = function()
            return not app:GetWindowSetting(frame.config, "hideTypeSelector")
        end,
        set = function(_, value)
            SetSkinOption(frame, "hideTypeSelector", not value)
        end,
    }
    local skinSetting = {
        name = "Skin",
        kind = lib.SettingType.Dropdown,
        default = "default",
        get = function()
            return frame.config.skin
        end,
        set = function(_, value)
            if not frame.syncingEditMode and app:IsEditingWindows() and not InCombatLockdown() then
                frame.config.skin = value
                app:RebuildWindows()
                lib:RefreshFrameSettings(frame)
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
    -- Reset selects Default and shared editing before resetting appearance controls.
    table.insert(settings, styleStart + 1, skinSetting)
    table.insert(settings, styleStart + 2, {
        name = "Modify global style",
        kind = lib.SettingType.Checkbox,
        default = true,
        desc = "On: Edit the shared skin.\nOff: Edit only this window.\nLocal overrides are kept when switching.",
        get = function()
            return frame.config.modifyGlobalStyle ~= false
        end,
        set = function(_, value, fromReset)
            if frame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
                return
            end
            frame.config.modifyGlobalStyle = value
            if fromReset then
                frame.config.styleOverrides = nil
            end
            app:RebuildWindows()
        end,
    })
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
        lib:AddFrame(
            frame,
            function(movedFrame, layoutName, point, x, y)
                if movedFrame.syncingEditMode or InCombatLockdown() or not app:IsEditingWindows() then
                    return
                end
                if not app:GetWindowSetting(movedFrame.config, "lockPosition") then
                    if movedFrame.config.anchorTo then
                        -- Linked anchors use independent points: convert the resulting screen position.
                        app:SaveWindowPosition(movedFrame, true)
                    else
                        local overrides = movedFrame.config.overrides
                        overrides.point, overrides.relativePoint = point, point
                        overrides.x, overrides.y = x, y
                    end
                    SaveLayout(movedFrame.config, layoutName)
                end
                app:PositionWindow(movedFrame)
                app.core:RefreshOptions("SeamlessDamageMeter")
            end,
            { point = app.windowDefaults.point, x = app.windowDefaults.x, y = app.windowDefaults.y },
            "Seamless Damage " .. frame.windowID
        )
        RegisterControls(frame)
    end
    frame:SetScale(self:GetWindowSetting(frame.config, "scale"))
    self:PositionWindow(frame)
    local editing = self:IsEditingWindows()
    frame.resize:SetFrameStrata(editing and "HIGH" or frame:GetFrameStrata())
    frame.resize:EnableMouse(not self:GetWindowSetting(frame.config, "lockSize"))
    if editing then
        frame.resize:SetAlpha(1)
    else
        frame:SetMovable(true)
    end
    frame.syncingEditMode = nil
    registered[frame] = frame.config
    SaveLayout(frame.config, activeLayout)
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
lib:RegisterCallback("layout", function(layoutName)
    activeLayout = layoutName
    app:ApplyEditModeLayout()
    RefreshEditMode()
end)

local function LayoutRecords(callback)
    if not app.db then
        return
    end
    -- Native layout names are shared across AceDB profiles, including inactive profiles.
    for _, profile in pairs(app.db.profiles) do
        for _, config in ipairs(profile.windows or {}) do
            if config.editModeLayouts then
                callback(config.editModeLayouts)
            end
        end
    end
end
lib:RegisterCallback("create", function(name, _, sourceName)
    LayoutRecords(function(records)
        if sourceName and records[sourceName] then
            local copy = {}
            for key, value in pairs(records[sourceName]) do
                copy[key] = value
            end
            records[name] = copy
        end
    end)
end)
lib:RegisterCallback("rename", function(oldName, newName)
    LayoutRecords(function(records)
        records[newName], records[oldName] = records[oldName], nil
    end)
    if activeLayout == oldName then
        activeLayout = newName
    end
end)
lib:RegisterCallback("delete", function(name)
    LayoutRecords(function(records)
        records[name] = nil
    end)
end)
