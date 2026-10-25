---@type string, SeamlessDamageMeter
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Layout controls inherit window defaults; appearance controls belong to skins. Position and scale
-- are each window's own values (`WindowPositionOptions`).
local settings = {
    { key = "width", name = L["Width"], type = "range", min = 200, max = 800, step = 1 },
    { key = "height", name = L["Height"], type = "range", min = 120, max = 900, step = 1 },
    {
        key = "fixedHeight",
        name = L["Fixed height by row count"],
        type = "toggle",
        desc = L["Keep the height at the bar count below. Resizing changes only the width."],
    },
    {
        key = "visibleLines",
        name = L["Visible bars"],
        type = "range",
        min = 1,
        max = 30,
        step = 0.25,
        desc = L["For fixed height. 7.5 shows seven bars and half of the next."],
    },
    {
        key = "showResizeHandle",
        name = L["Enable corner resizing"],
        type = "toggle",
        desc = L["Drag the bottom-right handle to resize. Turning this off hides it in Edit Mode too."],
    },
    {
        key = "lockSize",
        name = L["Lock size"],
        type = "toggle",
        desc = L["Prevent grip and Edit Mode width/height resizing."],
    },
    {
        key = "lockPosition",
        name = L["Lock position outside Edit Mode"],
        type = "toggle",
        desc = L["Prevent dragging the window outside Edit Mode. Edit Mode can still move it."],
    },
    {
        key = "font",
        name = L["Font"],
        type = "select",
        values = function()
            local values = { ["Default damage meter"] = L["Default damage meter"] }
            for name in pairs(LibStub("LibSharedMedia-3.0"):HashTable("font")) do
                values[name] = name
            end
            return values
        end,
    },
    { key = "windowAlpha", name = L["Window opacity"], type = "range", min = 0.5, max = 1, step = 0.01 },
    { key = "showIcons", name = L["Show icons"], type = "toggle" },
    { key = "fontSize", name = L["Font size"], type = "range", min = 8, max = 24, step = 1 },
    {
        key = "fontFlags",
        name = L["Font outline"],
        type = "select",
        values = { [""] = L["None"], OUTLINE = L["Outline"], THICKOUTLINE = L["Thick outline"] },
    },
    { key = "textColor", name = L["Text color"], type = "color" },
    { key = "classColors", name = L["Use class colors"], type = "toggle" },
    { key = "hideTypeSelector", name = L["Hide type selector"], type = "toggle" },
    { key = "hideCombatTimer", name = L["Hide combat timer"], type = "toggle" },
    { key = "barColor", name = L["Bar color"], type = "color" },
    { key = "backgroundColor", name = L["Window background"], type = "color" },
    { key = "headerColor", name = L["Header tint"], type = "color" },
    { key = "rowHeight", name = L["Row height"], type = "range", min = 16, max = 40, step = 1 },
    { key = "rowSpacing", name = L["Row spacing"], type = "range", min = 0, max = 12, step = 1 },
}

local function CopyValue(value)
    if type(value) == "table" then
        return { unpack(value) }
    end
    return value
end

local function SettingControl(definition, windowID, inherited, skin)
    local key = definition.key
    local control = {
        type = definition.type,
        name = windowID and (inherited and L["Default"] or (definition.desc and definition.name or L["Window value"]))
            or definition.name,
        desc = definition.desc,
        width = windowID and 0.75 or "full",
        min = definition.min,
        max = definition.max,
        step = definition.step,
        values = definition.values,
        get = function()
            local config = windowID and app.db.profile.windows[windowID]
            local value
            if skin then
                value = skin.settings[key]
            elseif not config or inherited then
                value = app.db.profile.windowDefaults[key]
            else
                value = app:GetWindowSetting(config, key)
            end
            if definition.type == "color" then
                return unpack(value)
            end
            return value
        end,
        set = function(_, value, g, b, a)
            local config = windowID and app.db.profile.windows[windowID]
            local target = skin and skin.settings or (config and config.overrides or app.db.profile.windowDefaults)
            if definition.type == "color" then
                target[key] = { value, g, b, a }
            else
                target[key] = value
            end
            app:RebuildWindows()
        end,
    }
    if definition.type == "color" then
        control.hasAlpha = true
    end
    if windowID then
        control.disabled = function()
            local config = windowID and app.db.profile.windows[windowID]
            return inherited or config.overrides[key] == nil
        end
    end
    return control
end

function app.WindowAppearanceOptions(windowID)
    local args = {
        info = {
            type = "description",
            order = 0,
            name = windowID
                    and L["Defaults are shown on the left. Enable Override to edit a window value. Turn it off to follow future default changes. Resizing sets width/height overrides.\n"]
                or L["Shared settings for every window without an override, including newly created windows.\n"],
        },
    }
    for order, definition in ipairs(settings) do
        local key = definition.key
        if app.skinDefaults[key] == nil then
            if windowID then
                local default = SettingControl(definition, windowID, true)
                default.order = 1
                local value = SettingControl(definition, windowID, false)
                value.order = 3
                args[key] = {
                    type = "group",
                    inline = true,
                    name = definition.name,
                    order = order * 10,
                    args = {
                        default = default,
                        override = {
                            type = "toggle",
                            name = L["Override"],
                            order = 2,
                            width = 0.5,
                            get = function()
                                local config = app.db.profile.windows[windowID]
                                return config.overrides[key] ~= nil
                            end,
                            set = function(_, enabled)
                                local config = app.db.profile.windows[windowID]
                                config.overrides[key] = enabled and CopyValue(app.db.profile.windowDefaults[key]) or nil
                                -- A false toggle value is itself a valid override.
                                if enabled and app.db.profile.windowDefaults[key] == false then
                                    config.overrides[key] = false
                                end
                                app:RebuildWindows()
                            end,
                        },
                        value = value,
                    },
                }
            else
                args[key] = SettingControl(definition)
                args[key].order = order * 10
            end
        end
    end
    return args
end

-- The standard Position and scale section, on the window's own values. Moving or re-anchoring
-- keeps the offsets; dragging the window measures them again.
function app.WindowPositionOptions(windowID)
    local group = app.core:GetPositionOptions({
        get = function(key)
            local config = app.db.profile.windows[windowID]
            if key == "relativeTo" then
                return config.anchorTo and tostring(config.anchorTo) or "screen"
            end
            return app:GetWindowSetting(config, key)
        end,
        set = function(key, value)
            local config = app.db.profile.windows[windowID]
            if key == "relativeTo" then
                config.anchorTo = tonumber(value)
            else
                app:SetWindowValue(config, key, value)
            end
            app:RebuildWindows()
        end,
        default = function(key)
            local config = app.db.profile.windows[windowID]
            if key == "relativeTo" then
                return "screen"
            end
            return app.positionDefaults[key]
        end,
        isDefault = function()
            local config = app.db.profile.windows[windowID]
            for key in pairs(app.positionDefaults) do
                if key ~= "scale" and app:GetWindowSetting(config, key) ~= app.positionDefaults[key] then
                    return false
                end
            end
            return config.anchorTo == nil
        end,
        reset = function()
            local config = app.db.profile.windows[windowID]
            for key in pairs(app.positionDefaults) do
                if key ~= "scale" then
                    app:SetWindowValue(config, key, app.positionDefaults[key])
                end
            end
            config.anchorTo = nil
            app:RebuildWindows()
        end,
        anchorFrames = function()
            local config = app.db.profile.windows[windowID]
            local values = { { text = L["Screen (UIParent)"], value = "screen" } }
            for _, candidate in ipairs(app.db.profile.windows) do
                if app:CanAnchorTo(config, candidate.id) then
                    values[#values + 1] = { text = L["Window %d"]:format(candidate.id), value = tostring(candidate.id) }
                end
            end
            return values
        end,
        scale = {
            get = function()
                local config = app.db.profile.windows[windowID]
                return app:GetWindowSetting(config, "scale")
            end,
            set = function(value)
                local config = app.db.profile.windows[windowID]
                app:SetWindowValue(config, "scale", value)
                app:RebuildWindows()
            end,
            default = function()
                local config = app.db.profile.windows[windowID]
                return app.positionDefaults.scale
            end,
        },
    })
    group.order = 2
    return group
end

-- Profiles replace saved window records; all declared accessors resolve the current record.
function app:BuildWindowOptions()
    self:PrepareWindowSettings()
end

app.meterSettingDefinitions = settings
app.MeterSettingControl = SettingControl

---Custom footer actions, declared by each window's options config.
---@return SeamlessCore.EditModeButton[]
function app.WindowEditModeButtons()
    local lib = app.core:GetEditModeLibrary()
    return {
        {
            kind = lib.SettingType.Button,
            name = L["Edit selected skin"],
            click = function()
                if not InCombatLockdown() then
                    app.core:OpenOptions("SeamlessDamageMeter", "skin")
                end
            end,
        },
        {
            kind = lib.SettingType.Button,
            name = L["Create new window"],
            click = function()
                if app:IsEditingWindows() and not InCombatLockdown() then
                    app:AddWindow()
                end
            end,
        },
        {
            kind = lib.SettingType.Button,
            name = L["Remove window"],
            click = function(frame)
                if app:IsEditingWindows() and not InCombatLockdown() then
                    EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                    app:SetWindowEnabled(frame.config, false)
                end
            end,
        },
    }
end
