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

-- The bar's settings in the current profile: `enabled` and one table per feature.
---@param bar StatusBar
---@return table?
function app.Settings(bar)
    local key = keys[bar]
    return key and app.db.profile[key]
end

-- Whether the features apply to this bar in the current profile.
---@param bar StatusBar
function app.Active(bar)
    local settings = app.Settings(bar)
    return settings ~= nil and settings.enabled == true
end

---@param icon boolean whether the bar has the spell icon option
local function barDefaults(icon)
    return {
        enabled = true,
        castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
        rank = { enabled = true },
        ticks = { enabled = true },
        icon = icon and { enabled = true } or nil,
        hold = { enabled = false, success = 0.2, interrupt = 1 },
        -- Target and focus only: detached from the unit frame and placed per Edit Mode layout.
        move = not icon and { enabled = false, layouts = {} } or nil,
    }
end

function app.addon:OnInitialize()
    app.db = LibStub("AceDB-3.0"):New("SeamlessCastbarDB", {
        profile = { player = barDefaults(true), target = barDefaults(false), focus = barDefaults(false) },
    }, true)
    app.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
    app.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    app.db.RegisterCallback(self, "OnProfileReset", "Refresh")
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
            -- Target and focus bars: the unit frame places them here.
            if bar.AdjustPosition then
                self:SecureHook(bar, "AdjustPosition", function(castBar)
                    app.UpdateMove(castBar, true)
                end)
            end
        end
    end
    app.RegisterEditMode()
    app.RegisterMove()
    self:Refresh()
end

function app.addon:OnDisable()
    self:UnhookAll()
    for bar in pairs(keys) do
        app.RestoreCastTime(bar)
        app.RestoreName(bar)
        app.HideTicks(bar)
        app.RestoreIcon(bar)
        app.RestoreHold(bar)
        app.UpdateMove(bar)
    end
    wipe(keys)
    app.core:RefreshEditModeSystemOptions()
end

function app.addon:Refresh()
    app.core:RefreshEditModeSystemOptions()
    if not self:IsEnabled() then
        return
    end
    for bar in pairs(keys) do
        if app.Active(bar) then
            app.UpdateName(bar)
            app.UpdateTicks(bar)
            app.UpdateCastTime(bar)
            app.UpdateIcon(bar)
            app.ApplyHold(bar)
        else
            app.RestoreCastTime(bar)
            app.RestoreName(bar)
            app.HideTicks(bar)
            app.RestoreIcon(bar)
            app.RestoreHold(bar)
        end
        app.UpdateMove(bar)
    end
end
