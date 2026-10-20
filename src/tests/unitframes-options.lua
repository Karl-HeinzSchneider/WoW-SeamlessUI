-- Run from the repository root: lua src/tests/unitframes-options.lua
local root = "SeamlessUnitframes/src/core/"

-- Locale: the English baseline through the real AceLocale.
GetLocale = function()
    return "enUS"
end
geterrorhandler = function()
    return function(message)
        error(message)
    end
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")

local cvars = { threatShowNumeric = "0" }
GetCVarBool = function(name)
    return cvars[name] == "1"
end
SetCVar = function(name, value)
    cvars[name] = value
end
PlayerFrame, PetFrame, TargetFrame, TargetFrameToT, FocusFrame = {}, {}, {}, {}, {}
-- FocusFrameToT is missing: its rows and tab are hidden.

local counts =
    { optionRefreshes = 0, systemRefreshes = 0, healthColor = 0, names = 0, questLayout = 0, questRefresh = 0 }
local registeredOptions, systemOptions, enabled = nil, {}, true
local modules = {}
local app = {
    db = {
        profile = {
            layout = "current",
            unitFrames = setmetatable({}, {
                __index = function(self, key)
                    local frame = { healthBarColor = "classReaction", nameDisplay = "full" }
                    rawset(self, key, frame)
                    return frame
                end,
            }),
            targetQuestIcon = { enabled = false, scale = 1.7, x = -30, y = 25 },
        },
    },
    core = {
        RegisterOptions = function(_, name, spec)
            assert(name == "SeamlessUnitframes")
            registeredOptions = spec
        end,
        RefreshOptions = function()
            counts.optionRefreshes = counts.optionRefreshes + 1
        end,
        RegisterEditModeSystemOptions = function(_, id, spec)
            assert(not systemOptions[id], "registered once")
            systemOptions[id] = spec
        end,
        RefreshEditModeSystemOptions = function()
            counts.systemRefreshes = counts.systemRefreshes + 1
        end,
    },
    addon = {
        NewModule = function(_, name, module)
            modules[name] = module
            return module
        end,
        IsEnabled = function()
            return enabled
        end,
    },
    healthColor = {
        Refresh = function()
            counts.healthColor = counts.healthColor + 1
        end,
    },
    nameDisplay = {
        Refresh = function()
            counts.names = counts.names + 1
        end,
    },
    targetQuestIcon = {
        ApplyLayout = function()
            counts.questLayout = counts.questLayout + 1
        end,
        OnProfileRefresh = function()
            counts.questRefresh = counts.questRefresh + 1
        end,
    },
}
local function load(file)
    assert(loadfile(root .. file))("SeamlessUnitframes", app)
end
load("unitframes.lua")
load("style.lua")
load("options.lua")
load("editmode.lua")

-- Options: layout stays in General, every unit frame has a tab of its own.
modules.Options.RegisterEvent = function() end
modules.Options:OnInitialize()
local general, tabs = registeredOptions.general, registeredOptions.tabs
assert(general.layout and not general.healthBarColors, "only the layout is global")
for _, key in ipairs({ "player", "pet", "target", "targettarget", "focus", "focustarget", "party" }) do
    assert(tabs[key], "tab for " .. key)
end
assert(tabs.player.order < tabs.pet.order and tabs.pet.order < tabs.target.order)
assert(not tabs.target.hidden() and tabs.focustarget.hidden(), "missing frames hide their tab")
assert(not tabs.party.hidden(), "party always counts")

local function find(tab, key)
    for _, group in pairs(tab.args) do
        if group.args[key] then
            return group.args[key]
        end
    end
end
local playerColor = find(tabs.player, "player_healthBarColor")
assert(playerColor.type == "select" and playerColor.values.class == "Class" and #playerColor.sorting == 4)
playerColor.set(nil, "reaction")
assert(app.db.profile.unitFrames.player.healthBarColor == "reaction" and playerColor.get() == "reaction")
assert(counts.healthColor == 1 and counts.optionRefreshes == 1 and counts.systemRefreshes == 1)
assert(not find(tabs.player, "threatPercentage"), "threat is a target option")
assert(find(tabs.pet, "pet_healthBarColor").desc:find("owner's class color"), "pet hint")
local partyName = find(tabs.party, "party_nameDisplay")
assert(partyName.values.first == "First name only" and partyName.sorting[1] == "full")
partyName.set(nil, "first")
assert(app.db.profile.unitFrames.party.nameDisplay == "first" and counts.names == 1)

local threat = find(tabs.target, "threatPercentage")
threat.set(nil, true)
assert(cvars.threatShowNumeric == "1" and threat.get() == true)
local scale = find(tabs.target, "questIcon_scale")
assert(scale.disabled(), "quest icon sliders follow their switch")
find(tabs.target, "questIcon_enabled").set(nil, true)
assert(counts.questRefresh == 1 and not scale.disabled())
scale.set(nil, 0.30000000000000004 + 2)
assert(app.db.profile.targetQuestIcon.scale == 2.3 and counts.questLayout == 1)
print("PASS: one options tab per unit frame, layout in General")

-- Edit Mode: a Style section for each unit frame system, with linked frames in their owner's.
Enum = {
    EditModeSystem = { UnitFrame = 0 },
    EditModeUnitFrameSystemIndices = { Player = 1, Target = 2, Focus = 3, Party = 4, Pet = 7 },
}
modules.EditMode:OnEnable()
modules.EditMode:OnEnable()
local function rows(id)
    local spec = systemOptions["SeamlessUnitframes." .. id]
    assert(spec and spec.system == 0 and spec.name == "Style", id)
    local byKey, keys = {}, {}
    for _, row in ipairs(spec.options) do
        assert(not keys[row.key], "unique row keys")
        keys[row.key] = true
        byKey[row.key] = row
    end
    return spec, byKey
end
local playerSpec, playerRows = rows("player")
assert(playerSpec.systemIndex == 1 and playerSpec.enabled())
assert(not systemOptions["SeamlessUnitframes.targettarget"], "no section without a system")
local targetSpec, targetRows = rows("target")
assert(targetSpec.systemIndex == 2)
assert(targetRows["targettarget.healthBarColor"].name == "Target of Target health bar color")
assert(not targetRows["targettarget.healthBarColor"].hidden())
assert(targetRows["targettarget.nameDisplay"].name == "Target of Target name display")
assert(targetRows["target.nameDisplay"].name == "Name display")
assert(targetRows.threatPercentage and targetRows["questIcon.x"])
local _, focusRows = rows("focus")
assert(focusRows["focustarget.healthBarColor"].hidden(), "missing linked frame hides its row")
assert(focusRows["focustarget.nameDisplay"].hidden())
local _, petRows = rows("pet")
assert(rows("party") and petRows["pet.healthBarColor"].values[1].value == "default")

targetRows["targettarget.healthBarColor"].set("default")
assert(app.db.profile.unitFrames.targettarget.healthBarColor == "default")
assert(find(tabs.targettarget, "targettarget_healthBarColor").get() == "default", "same profile as the tab")
playerRows["player.healthBarColor"].set("class")
assert(playerColor.get() == "class")
assert(targetRows["questIcon.scale"].format(2.3) == "2.3")
enabled = false
assert(not playerSpec.enabled(), "the section leaves while the addon is disabled")
targetRows["targettarget.nameDisplay"].set("last")
assert(find(tabs.targettarget, "targettarget_nameDisplay").get() == "last")
print("PASS: unit frame Style sections in Edit Mode")

-- Name display: first name or surname on the game's frames, the game's text back for full.
local names = { player = { "Anna", "Weber" }, target = { "Hogger" }, party1 = { "Bob-Smith" } }
UnitName = function(unit)
    return unpack(names[unit])
end
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = "-" } }
local function FontString(text)
    return {
        GetText = function()
            return text
        end,
        SetText = function(_, value)
            text = value
        end,
    }
end
local hooked
hooksecurefunc = function(name, fn)
    assert(name == "UnitFrame_Update")
    hooked = fn
end
enabled = true
PlayerFrame.unit, PlayerFrame.name = "player", FontString("Anna Weber")
TargetFrame.unit, TargetFrame.name = "target", FontString("Hogger")
local member = { unit = "party1", name = FontString("Bob-Smith") }
PartyFrame = { MemberFrame1 = member }
app.nameDisplay = nil
app.db.profile.unitFrames.player.nameDisplay = "first"
app.db.profile.unitFrames.target.nameDisplay = "last"
app.db.profile.unitFrames.party.nameDisplay = "last"
loadfile("SeamlessUnitframes/src/name/namedisplay.lua")("SeamlessUnitframes", app)
local nameDisplay = modules.NameDisplay
nameDisplay:OnInitialize()
hooked(PlayerFrame)
assert(PlayerFrame.name:GetText() == "Anna", "first name")
hooked(TargetFrame)
assert(TargetFrame.name:GetText() == "Hogger", "no surname keeps the name")
hooked(member)
assert(member.name:GetText() == "Smith", "joined surname")
app.db.profile.unitFrames.player.nameDisplay = "last"
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "Weber")
app.db.profile.unitFrames.player.nameDisplay = "full"
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "Anna Weber", "the game's text restored")
PlayerFrame.name:SetText("Anna Weber")
hooked(PlayerFrame)
assert(PlayerFrame.name:GetText() == "Anna Weber")
canaccessvalue = function(value)
    return value ~= "secret"
end
names.player = { "secret" }
app.db.profile.unitFrames.player.nameDisplay = "first"
hooked(PlayerFrame)
assert(PlayerFrame.name:GetText() == "Anna Weber", "secret names are left alone")
canaccessvalue = nil
enabled = false
nameDisplay:OnDisable()
assert(member.name:GetText() == "Bob-Smith", "disabled restores the game's text")
print("PASS: name display")
