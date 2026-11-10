-- lua src/tests/player-castbar.lua
local app = { db = { profile = { player = { castTime = { enabled = true }, showCastTime = true } } } }
local active = true
app.ApplyPlayerPosition = function() end
app.InitializePlayerSettings = function() end
app.IsPlayerEditMode = function()
    return false
end
app.InstallCraftingBar = function() end
app.EnableCraftingBar = function() end
app.DisableCraftingBar = function() end
app.addon = {
    IsEnabled = function()
        return active
    end,
}
local calls = {}
for _, method in ipairs({
    "UpdateCastTime",
    "UpdateName",
    "UpdateTicks",
    "UpdateIcon",
    "HideTicks",
    "ApplyPlayerSize",
}) do
    app[method] = function()
        calls[method] = (calls[method] or 0) + 1
    end
end
UIParent = {
    GetEffectiveScale = function()
        return 0.8
    end,
}
PlayerFrame = {
    GetEffectiveScale = function()
        return 1.2
    end,
}
app.PlayerSizeDefault = function()
    return 1
end
Enum = { EditModeSystem = { CastBar = 4 }, EditModeCastBarSetting = { LockToPlayerFrame = 1, ShowCastTime = 2 } }
local lock = { setting = 1, value = 0 }
local time = { setting = 2, value = 1 }
local layout = { systems = { { system = 4, settings = { lock, time } } } }
EditModeManagerFrame = {
    GetActiveLayoutInfo = function()
        return layout
    end,
}
-- Reading any native cast state or method is an error; only the anchor may reference it.
PlayerCastingBarFrame = setmetatable({}, {
    __index = function()
        error("read native castbar")
    end,
})
local created = 0
local inherited = {}
CreateFrame = function(kind, name, parent, template)
    assert(kind == "StatusBar" and name == "SeamlessCastbarPlayer")
    assert(parent == UIParent and template == "CastingBarFrameTemplate")
    created = created + 1
    local frame = {}
    function frame:Hide()
        self.hidden = true
    end
    function frame:SetFrameStrata(value)
        assert(value == "HIGH")
    end
    function frame:SetScale(value)
        self.scale = value
    end
    function frame:GetScript(script)
        assert(script == "OnEvent")
        return function(self, event)
            self.lastEvent = event
        end
    end
    function frame:SetScript(script, callback)
        self[script] = callback
    end
    function frame:SetPoint(point, anchor, relative, x, y)
        assert(point == "BOTTOM" and anchor == PlayerCastingBarFrame and relative == "TOP" and x == 0 and y == 32)
    end
    function frame:SetLook(value)
        self.look = value
    end
    function frame:SetCastTimeTextShown(value)
        self.timeShown = value
    end
    function frame:SetIconShown(value)
        self.iconShown = value
        self:UpdateIconShown()
    end
    function frame:SetUnit(unit, trade, shield)
        assert(trade and not shield)
        self.unit = unit
    end
    function frame:HookScript(script, callback)
        self[script] = callback
    end
    for _, method in ipairs({
        "UpdateCastTimeText",
        "HandleCastStart",
        "HandleChannelUpdateDelayed",
        "HandleCastDelayed",
        "UpdateIconShown",
    }) do
        inherited[method] = function(self, ...)
            self.lastMethod = method
            self.lastArgument = ...
        end
        frame[method] = inherited[method]
    end
    return frame
end
assert(loadfile("SeamlessCastbar/src/player.lua"))("SeamlessCastbar", app)
app.EnablePlayerBar()
local bar = app.GetPlayerBar()
assert(bar.unit == "player" and bar.look == "CLASSIC" and bar.timeShown)
bar:HandleCastStart("UNIT_SPELLCAST_START")
assert(bar.lastArgument == "UNIT_SPELLCAST_START" and calls.UpdateName == 1 and calls.UpdateTicks == 1)
bar:HandleChannelUpdateDelayed()
assert(calls.UpdateTicks == 2)
bar:UpdateCastTimeText()
assert(calls.UpdateCastTime == 2)
app.db.profile = { player = { castTime = { enabled = false }, showCastTime = true } }
app.RefreshPlayerBar()
assert(bar.timeShown, "formatting toggle must not override shared Show Cast Time visibility")
lock.value = 1
time.value = 0
bar:OnEvent("UNIT_SPELLCAST_START")
assert(bar.look == "CLASSIC" and bar.timeShown and bar.iconShown)
assert(bar.scale == 1, "native lock setting cannot change our scale")
assert(bar.lastEvent == "UNIT_SPELLCAST_START", "own inherited event handler still runs")
lock.value = 0
time.value = 1
bar:OnUpdate()
assert(bar.look == "CLASSIC" and bar.timeShown and bar.scale == 1)
assert(bar.iconShown, "native icon eligibility stays enabled for both looks")
app.db.profile.player.scale = 1.7
app.RefreshPlayerBar(true)
assert(bar.scale == 1.7, "profile changes apply independently")
app.DisablePlayerBar()
assert(bar.unit == nil and bar.hidden)
app.EnablePlayerBar()
assert(created == 1 and bar.unit == "player", "reenable reuses the frame without stacking wrappers")
bar:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START")
assert(calls.UpdateName == 2)
print("PASS: independent player castbar lifecycle, method dispatch and profile refresh")

-- Sizing resolves only the custom frame and never reads native geometry.
assert(loadfile("SeamlessCastbar/src/size.lua"))("SeamlessCastbar", app)
local dimensions = {}
bar.SetWidth = function(_, value)
    dimensions.width = value
end
bar.SetHeight = function(_, value)
    dimensions.height = value
end
bar.SetScale = function(_, value)
    dimensions.scale = value
end
app.dbDefaults = { profile = { player = { width = 208, height = 11, scale = 1, iconSize = 16 } } }
app.db.profile.player.width = 250
app.db.profile.player.height = 20
app.db.profile.player.scale = 1.5
app.ApplyPlayerSize()
assert(dimensions.width == 250 and dimensions.height == 20 and dimensions.scale == 1.5)
app.db.profile = { player = {} }
app.RefreshPlayerBar(true)
assert(dimensions.width == 208 and dimensions.height == 11 and dimensions.scale == 1)
active = false
app.db.profile.player.width = 300
app.ApplyPlayerSize()
assert(dimensions.width == 208, "disabled sizing does not mutate the hidden frame")
print("PASS: custom player sizing uses current profile and defaults without native geometry")

-- Core must never hook native appearance or include the native player in feature refreshes.
local nativeShown = true
PlayerCastingBarFrame = setmetatable({
    showCastbar = true,
    SetAndUpdateShowCastbar = function(_, shown)
        nativeShown = shown
    end,
    Hide = function() end,
}, {
    __index = function(_, key)
        error("read native appearance: " .. key)
    end,
})
local hooks = {}
local addon = {
    SecureHook = function(_, frame, method)
        if frame == PlayerCastingBarFrame then
            assert(method == "SetAndUpdateShowCastbar", "native appearance must not be hooked")
            hooks[method] = true
        end
    end,
    SecureHookScript = function(_, frame, script)
        assert(frame == PlayerCastingBarFrame and script == "OnShow")
    end,
    UnhookAll = function() end,
}
local core = { RefreshEditModeSystemOptions = function() end }
LibStub = function()
    return {
        GetAddon = function()
            return core
        end,
        NewAddon = function()
            return addon
        end,
    }
end
assert(loadfile("SeamlessCastbar/src/core.lua"))("SeamlessCastbar", app)
app.position = { Enable = function() end, Disable = function() end }
for _, method in ipairs({
    "RegisterPreviews",
    "EnablePlayerBar",
    "RegisterPlayerEditMode",
    "DisablePlayerBar",
    "UpdatePlayerPreview",
    "UpdatePreviews",
    "RestoreCastTime",
    "RestoreName",
    "HideTicks",
    "RestoreIcon",
    "RestoreHold",
}) do
    app[method] = function(frame)
        assert(frame ~= PlayerCastingBarFrame, "native bar included in feature restoration")
    end
end
addon.Refresh = function() end
wipe = function(t)
    for key in pairs(t) do
        t[key] = nil
    end
end
addon:OnEnable()
assert(hooks.SetAndUpdateShowCastbar and not nativeShown)
assert(app.BarKey(PlayerCastingBarFrame) == nil and app.BarKey(bar) == "player")
addon:OnDisable()
assert(nativeShown, "disable restores native display eligibility")
print("PASS: native player is only suppressed, never hooked for appearance")
