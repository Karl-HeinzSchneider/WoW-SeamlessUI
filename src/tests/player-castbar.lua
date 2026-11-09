-- lua src/tests/player-castbar.lua
local app = { db = { profile = { player = { castTime = { enabled = true } } } } }
local active = true
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
    "PlayerSizeLookChanged",
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
app.db.profile = { player = { castTime = { enabled = false } } }
app.RefreshPlayerBar()
assert(bar.timeShown, "formatting toggle must not override shared Show Cast Time visibility")
lock.value = 1
time.value = 0
bar:OnEvent("UNIT_SPELLCAST_START")
assert(bar.look == "UNITFRAME" and not bar.timeShown and bar.iconShown)
assert(math.abs(bar.scale - 1.5) < 0.0001, "locked appearance uses PlayerFrame's inherited scale rule")
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

-- Both player bars share settings but must retain their own restoration dimensions.
assert(loadfile("SeamlessCastbar/src/size.lua"))("SeamlessCastbar", app)
local function sizedBar(width, height, scale)
    return {
        GetWidth = function()
            return width
        end,
        GetHeight = function()
            return height
        end,
        GetScale = function()
            return scale
        end,
        SetWidth = function(_, value)
            width = value
        end,
        SetHeight = function(_, value)
            height = value
        end,
        SetScale = function(_, value)
            scale = value
        end,
    }
end
local original = sizedBar(208, 11, 1)
local custom = sizedBar(150, 10, 0.8)
PlayerCastingBarFrame = original
app.db.profile.player.width = 250
app.db.profile.player.height = 20
app.db.profile.player.scale = 1.5
app.ApplyPlayerSize()
app.ApplyPlayerSize(custom)
assert(original:GetWidth() == 250 and custom:GetWidth() == 250)
assert(original:GetHeight() == 20 and custom:GetHeight() == 20)
assert(original:GetScale() == 1.5 and custom:GetScale() == 1.5)
active = false
app.ApplyPlayerSize()
app.ApplyPlayerSize(custom)
assert(original:GetWidth() == 208 and custom:GetWidth() == 150)
assert(original:GetHeight() == 11 and custom:GetHeight() == 10)
assert(original:GetScale() == 1 and custom:GetScale() == 0.8)
print("PASS: both player bars share dimensions and restore independently")
