---@type string, SeamlessActionBars
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- Bars whose `actionButtons` use the client's action button mixin (`UpdateUsable`,
-- `UpdateHotkeys`). Pet, stance and possess buttons are built differently and are left alone.
local bars = {
    "MainActionBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

---@type table<CheckButton, true>
local watched = {}
local pendingIconRefresh

-- Blizzard_ActionBar/Shared/ActionButton.lua updates usability from these events and
-- ACTION_USABLE_CHANGED. Paint on the next frame, after the native event handlers,
-- without hooking or calling the buttons' UpdateUsable methods.
function app.addon:QueueIconRefresh()
    if pendingIconRefresh then
        return
    end
    local pending = {}
    pendingIconRefresh = pending
    C_Timer.After(0, function()
        if pendingIconRefresh ~= pending then
            return
        end
        pendingIconRefresh = nil
        if self:IsEnabled() then
            for button in pairs(watched) do
                app.PaintIcon(button)
            end
        end
    end)
end

---@return CheckButton[]
function app.Buttons()
    local buttons = {}
    for _, name in ipairs(bars) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

function app.addon:OnInitialize()
    app.dbDefaults = app.core:GetOptionsDefaults(app.optionPages, app.dbDefaults)
    app.db = app.core:RegisterAddonDatabase(appName, app.dbDefaults, self, "Refresh", "SeamlessActionBarsDB")
    self:RegisterChatCommand("seamlessactionbars", function()
        app.core:OpenOptions(appName)
    end)
    app.RegisterEndCapEditMode()
end

function app.addon:OnEnable()
    for _, button in ipairs(app.Buttons()) do
        watched[button] = true
        self:SecureHook(button, "UpdateHotkeys", app.UpdateHotkey)
    end
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "ACTION_USABLE_CHANGED",
        "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_BONUS_ACTIONBAR",
        "UPDATE_SHAPESHIFT_FORM",
        "PLAYER_MOUNT_DISPLAY_CHANGED",
        "UPDATE_VEHICLE_ACTIONBAR",
        "SPELL_UPDATE_ICON",
    }) do
        self:RegisterEvent(event, "QueueIconRefresh")
    end
    -- A global shared with the pet bar, called on every ACTION_RANGE_CHECK_UPDATE.
    self:SecureHook("ActionButton_UpdateRangeIndicator", function(button)
        if watched[button] then
            app.PaintIcon(button)
        end
    end)
    self:Refresh()
    self:QueueIconRefresh()
    app.core:RefreshEditModeSystemOptions()
end

function app.addon:OnDisable()
    pendingIconRefresh = nil
    self:UnhookAll()
    self:UnregisterAllEvents()
    app.RefreshBagStyle()
    app.RefreshStatusBarScale()
    app.ApplyEndCaps(true)
    app.core:RefreshEditModeSystemOptions()
    for button in pairs(watched) do
        app.RestoreIcon(button)
        app.RestoreHotkey(button)
    end
    wipe(watched)
end

function app.addon:Refresh()
    if not self:IsEnabled() then
        return
    end
    for button in pairs(watched) do
        app.PaintIcon(button)
        app.UpdateHotkey(button)
    end
    app.xpBarTooltip:OnProfileRefresh()
    app.ApplyEndCaps()
    app.RefreshMicroMenu()
    app.RefreshBarVisibility()
    app.RefreshBagStyle()
    app.RefreshStatusBarScale()
end
