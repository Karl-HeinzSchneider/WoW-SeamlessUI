---@type string, SeamlessActionBars
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end

-- Native Edit Mode frames, one Position and scale tab each, in tab order. Bars 4 and 5 follow
-- the client's numbering (Action Bar 4 is MultiBarRight). Scale is the frame's own size setting
-- (Icon Size, status bar Size); the leave vehicle button has none, so its Scale stays disabled.
local frames = {
    { key = "bar1", frame = "MainActionBar", size = "ActionBar" },
    { key = "bar2", frame = "MultiBarBottomLeft", size = "ActionBar" },
    { key = "bar3", frame = "MultiBarBottomRight", size = "ActionBar" },
    { key = "bar4", frame = "MultiBarRight", size = "ActionBar" },
    { key = "bar5", frame = "MultiBarLeft", size = "ActionBar" },
    { key = "bar6", frame = "MultiBar5", size = "ActionBar" },
    { key = "bar7", frame = "MultiBar6", size = "ActionBar" },
    { key = "bar8", frame = "MultiBar7", size = "ActionBar" },
    { key = "statusBar1", frame = "MainStatusTrackingBarContainer", size = "StatusTrackingBar" },
    { key = "statusBar2", frame = "SecondaryStatusTrackingBarContainer", size = "StatusTrackingBar" },
    { key = "petBar", frame = "PetActionBar", size = "ActionBar", name = L["Pet action bar"] },
    { key = "vehicleLeave", frame = "MainMenuBarVehicleLeaveButton", name = L["Leave vehicle button"] },
    { key = "microMenu", frame = "MicroMenuContainer", size = "MicroMenu", name = L["Micro menu"] },
}
-- The gryphons have no global name and no native size setting: their Scale is our own, kept in
-- the profile (see endcaps.lua), and their tab adds the native Hidden setting.
for _, entry in ipairs(app.endCaps) do
    frames[#frames + 1] = {
        key = "endCap" .. entry.key:gsub("^%l", string.upper),
        name = entry.name,
        endCap = entry,
        get = function()
            return app.EndCapFrame(entry)
        end,
    }
end
for i = 1, 8 do
    frames[i].name = string.format(L["Action bar %d"], i)
end
for i = 1, 2 do
    frames[8 + i].name = string.format(L["XP / reputation bar %d"], i)
end

---The native setting used as Scale, or nil when the frame has none.
---@return number?
local function sizeSetting(size)
    if size == "ActionBar" then
        return Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.IconSize
    elseif size == "StatusTrackingBar" then
        return Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
    elseif size == "MicroMenu" then
        return Enum.EditModeMicroMenuSetting and Enum.EditModeMicroMenuSetting.Size
    end
end

local function frameGetter(entry)
    return entry.get or function()
        return _G[entry.frame]
    end
end

local function frameTab(entry, order)
    local getFrame = frameGetter(entry)
    local setting = sizeSetting(entry.size)
    local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
    if entry.endCap then
        scale = app.EndCapScale(entry.endCap)
    end
    return {
        order = order,
        name = entry.name,
        hidden = function()
            return getFrame() == nil
        end,
        args = {
            hidden = entry.endCap and app.EndCapHiddenOption(entry.endCap) or nil,
            position = app.core:GetNativePositionOptions(getFrame, scale or nil),
            layout = entry.key == "microMenu" and app.MicroMenuOptions() or nil,
        },
    }
end

-- Bars 2-8 are shown or hidden by the game's own Action Bars settings. Changing them from addon
-- code runs the bars' update in our call and taints the buttons (blocked SetShown in combat), so
-- this only opens that settings page, through the same secure call Edit Mode uses.
local showBars = {
    type = "execute",
    order = 5,
    name = L["Show action bars"],
    desc = L["Open the game's Action Bars settings to show or hide action bars 2 to 8. A hidden bar is not shown in Edit Mode either."],
    disabled = function()
        return Settings.ACTION_BAR_CATEGORY_ID == nil
    end,
    func = function()
        Settings.OpenToCategory(Settings.ACTION_BAR_CATEGORY_ID)
    end,
}

---@class SeamlessActionBars.Options : AceModule, AceEvent-3.0
---@field positionHooked? table<table, boolean> Frames whose native position and size changes refresh the options.
local options = app.addon:NewModule("Options", "AceEvent-3.0") --[[@as SeamlessActionBars.Options]]
function options:OnInitialize()
    local tabs = {}
    for i, entry in ipairs(frames) do
        tabs[entry.key] = frameTab(entry, i * 10)
    end
    app.core:RegisterOptions(appName, {
        tooltip = function(path)
            -- Position rows and the endcaps' Hide carry their own game defaults.
            if path[1] ~= "general" then
                return nil
            end
            local defaults = app.dbDefaults.profile[path[2]]
            return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
        end,
        title = L["Action Bars"],
        general = {
            bars = showBars,
            range = app.core.FeatureGroup({
                order = 10,
                name = L["Out of range"],
                desc = L["Color the icon of an action that is out of range of your target."],
                settings = function()
                    return app.db.profile.range
                end,
                toggled = refresh,
                changed = refresh,
                options = {
                    color = { type = "color", order = 1, name = L["Out of range color"], hasAlpha = false },
                },
            }),
            mana = app.core.FeatureGroup({
                order = 20,
                name = L["Not enough mana"],
                desc = L["Color the icon of an action you lack the mana, rage or energy for, instead of the game's light blue shade."],
                settings = function()
                    return app.db.profile.mana
                end,
                toggled = refresh,
                changed = refresh,
                options = {
                    color = { type = "color", order = 1, name = L["Not enough mana color"], hasAlpha = false },
                },
            }),
            keybinds = app.core.FeatureGroup({
                order = 30,
                name = L["Short keybind labels"],
                desc = L["Show keybinds as short labels, such as SM4 for Shift and mouse button 4, or N5 for num pad 5."],
                settings = function()
                    return app.db.profile.keybinds
                end,
                toggled = refresh,
            }),
        },
        tabs = tabs,
    })
end

-- Position and scale live in the native layout: redraw when it changes outside these options.
function options:OnEnable()
    local function refreshPosition()
        app.core:RefreshOptions(appName)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", refreshPosition)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", refreshPosition)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", refreshPosition)
    self.positionHooked = self.positionHooked or {}
    for _, entry in ipairs(frames) do
        local frame = frameGetter(entry)()
        if frame and not self.positionHooked[frame] then
            self.positionHooked[frame] = true
            for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSetting" }) do
                if frame[method] then
                    hooksecurefunc(frame, method, refreshPosition)
                end
            end
        end
    end
end
