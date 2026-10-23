-- Run from the repository root: lua src/tests/damage-meter-blizzard.lua
-- Blizzard's meter must never run addon code or be called by it: hiding only reparents it.
unpack = unpack or table.unpack
local parent = "UIParent"
local function Forbidden(name)
    return function()
        error(name .. " runs Blizzard's meter code in addon taint")
    end
end
DamageMeter = {
    SetParent = function(_, frame)
        parent = frame
    end,
    HookScript = Forbidden("HookScript"),
    SetScript = Forbidden("SetScript"),
    Hide = Forbidden("Hide"),
    Show = Forbidden("Show"),
    SetShown = Forbidden("SetShown"),
    UpdateShownState = Forbidden("UpdateShownState"),
}
C_CVar = { SetCVar = Forbidden("SetCVar") }
securecallfunction = Forbidden("securecallfunction")
hooksecurefunc = Forbidden("hooksecurefunc")
local created = 0
function CreateFrame()
    created = created + 1
    local frame = { hidden = false }
    function frame:Hide()
        self.hidden = true
    end
    return frame
end
local opened
Settings = {
    ADVANCED_OPTIONS_CATEGORY_ID = 42,
    OpenToCategory = function(id)
        opened = id
    end,
}
local app = { db = { profile = { hideBlizzard = false } } }
assert(loadfile("SeamlessDamageMeter/src/blizzard.lua"))("SeamlessDamageMeter", app)

app:HideBlizzardMeter()
assert(parent == "UIParent" and created == 0 and not app:IsBlizzardMeterHidden(), "Off leaves the meter alone")
app.db.profile.hideBlizzard = true
app:HideBlizzardMeter()
assert(type(parent) == "table" and parent.hidden and app:IsBlizzardMeterHidden(), "Hidden under a hidden parent")
local hiddenParent = parent
app:HideBlizzardMeter()
assert(parent == hiddenParent and created == 1, "Reparented once per session")
app.db.profile.hideBlizzard = false
app:HideBlizzardMeter()
assert(parent == hiddenParent, "Showing it again takes a reload, never a call into the meter")
app:OpenBlizzardMeterSettings()
assert(opened == 42, "The game's settings own the damageMeterEnabled CVar")
DamageMeter = nil
local fresh = { db = { profile = { hideBlizzard = true } } }
assert(loadfile("SeamlessDamageMeter/src/blizzard.lua"))("SeamlessDamageMeter", fresh)
fresh:HideBlizzardMeter()
assert(not fresh:IsBlizzardMeterHidden(), "Missing native meter is ignored")
print("PASS: native meter hidden by reparenting only, no hooks, calls or CVar writes; settings opened in the game")
