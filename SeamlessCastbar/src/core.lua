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

-- Whether the features apply to this bar in the current profile.
---@param bar StatusBar
function app.Active(bar)
    local key = keys[bar]
    return key ~= nil and app.db.profile.bars[key] == true
end

function app.addon:OnInitialize()
    app.db = LibStub("AceDB-3.0"):New("SeamlessCastbarDB", {
        profile = {
            bars = { player = true, target = true, focus = true },
            castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
            rank = { enabled = true },
            ticks = { enabled = true },
            icon = { enabled = true },
            hold = { enabled = false, success = 0.2, interrupt = 1 },
        },
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
        end
    end
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
    end
    wipe(keys)
end

function app.addon:Refresh()
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
    end
end
