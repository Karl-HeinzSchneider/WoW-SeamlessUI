---@type string, SeamlessCastbar
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- The game's own cast bars, by profile key. They all use the client's casting bar mixin; target
-- and focus bars are created by their unit frames.
local barNames = {
    player = "PlayerCastingBarFrame",
    target = "TargetFrameSpellBar",
    focus = "FocusFrameSpellBar",
}

---@type table<StatusBar, string>
local keys = {}

---@param bar StatusBar
---@return string?
function app.BarKey(bar)
    return keys[bar]
end

-- The bar's feature settings in the current profile.
---@param bar StatusBar
---@return table?
function app.Settings(bar)
    local key = keys[bar]
    return key and app.db.profile[key]
end

function app.addon:OnInitialize()
    app.dbDefaults = app.core:GetOptionsDefaults(app.optionPages, app.dbDefaults)
    app.db = app.core:RegisterAddonDatabase(appName, app.dbDefaults, self, "Refresh", "SeamlessCastbarDB")
    self:RegisterChatCommand("seamlesscastbar", function()
        app.core:OpenOptions(appName)
    end)
end

function app.addon:OnEnable()
    for key, name in pairs(barNames) do
        local bar = _G[name]
        if bar and bar.HandleCastStart then
            keys[bar] = key
            -- Called on every frame of a cast or channel, also on bars without the game's own
            -- cast time text (target, focus).
            self:SecureHook(bar, "UpdateCastTimeText", app.UpdateCastTime)
            self:SecureHook(bar, "HandleCastStart", function(castBar)
                app.UpdateName(castBar)
                app.UpdateTicks(castBar)
                app.UpdateCastTime(castBar)
            end)
            self:SecureHook(bar, "HandleChannelUpdateDelayed", app.UpdateTicks)
            -- A delayed cast that was not shown as casting turns the bar into a cast.
            self:SecureHook(bar, "HandleCastDelayed", app.UpdateTicks)
            self:SecureHook(bar, "UpdateIconShown", app.UpdateIcon)
            if key == "player" then
                self:SecureHook(bar, "SetLook", app.PlayerSizeLookChanged)
                self:SecureHook(bar, "UpdateSystemSettingBarSize", app.PlayerScaleChanged)
            end
        end
    end
    app.RegisterEditMode()
    app.RegisterPreviews()
    app.position:Enable()
    self:Refresh()
end

function app.addon:OnDisable()
    self:UnhookAll()
    app.ApplyPlayerSize()
    for bar in pairs(keys) do
        app.RestoreCastTime(bar)
        app.RestoreName(bar)
        app.HideTicks(bar)
        app.RestoreIcon(bar)
        app.RestoreHold(bar)
    end
    wipe(keys)
    app.position:Disable()
    app.UpdatePreviews()
    app.core:RefreshEditModeSystemOptions()
end

function app.addon:Refresh()
    app.core:RefreshEditModeSystemOptions()
    if not self:IsEnabled() then
        return
    end
    app.ApplyPlayerSize()
    for bar in pairs(keys) do
        app.UpdateName(bar)
        app.UpdateTicks(bar)
        app.UpdateCastTime(bar)
        app.UpdateIcon(bar)
        app.ApplyHold(bar)
    end
    app.position:Refresh()
    app.UpdatePreviews()
end
