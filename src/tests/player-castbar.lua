-- lua src/tests/player-castbar.lua
local app = { db = { profile = { player = { castTime = { enabled = true } } } } }
local active = true
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
}) do
    app[method] = function()
        calls[method] = (calls[method] or 0) + 1
    end
end
UIParent = {}
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
assert(not bar.timeShown, "refresh reads the current profile")
app.DisablePlayerBar()
assert(bar.unit == nil and bar.hidden)
app.EnablePlayerBar()
assert(created == 1 and bar.unit == "player", "reenable reuses the frame without stacking wrappers")
bar:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START")
assert(calls.UpdateName == 2)
print("PASS: independent player castbar lifecycle, method dispatch and profile refresh")
