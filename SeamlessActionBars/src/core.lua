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
    app.RegisterEndCapScales()
end

function app.addon:OnEnable()
    for _, button in ipairs(app.Buttons()) do
        watched[button] = true
        self:SecureHook(button, "UpdateUsable", app.PaintIcon)
        self:SecureHook(button, "UpdateHotkeys", app.UpdateHotkey)
    end
    -- A global shared with the pet bar, called on every ACTION_RANGE_CHECK_UPDATE.
    self:SecureHook("ActionButton_UpdateRangeIndicator", function(button)
        if watched[button] then
            app.PaintIcon(button)
        end
    end)
    -- Endcap scales skipped in combat.
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    self:Refresh()
    app.core:RefreshEditModeSystemOptions()
end

function app.addon:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    app.ApplyEndCapScales(true)
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
    app.ApplyEndCapScales()
    app.RefreshMicroMenu()
end
