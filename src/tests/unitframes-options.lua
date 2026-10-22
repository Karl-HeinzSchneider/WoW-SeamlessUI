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

local counts = {
    optionRefreshes = 0,
    systemRefreshes = 0,
    healthColor = 0,
    names = 0,
    classIcons = 0,
    pvpIcons = 0,
    questLayout = 0,
    questRefresh = 0,
}
local registeredOptions, systemOptions, enabled = nil, {}, true
local positioned = {}
Enum = { EditModeUnitFrameSetting = { FrameSize = 9 } }
local modules = {}
local app = {
    db = {
        profile = {
            layout = "current",
            unitFrames = setmetatable({}, {
                __index = function(self, key)
                    local frame = {
                        healthBarColor = "classReaction",
                        nameDisplay = "full",
                        classIcon = false,
                        hidePvPIcon = false,
                    }
                    rawset(self, key, frame)
                    return frame
                end,
            }),
            targetQuestIcon = { enabled = false, scale = 1.7, x = -30, y = 25 },
        },
    },
    totPosition = {
        GetOptions = function(_, key)
            if key == "targettarget" or key == "focustarget" then
                return { type = "group", inline = true, name = "Position and scale", order = 10, args = {} }
            end
        end,
    },
    core = {
        GetNativePositionOptions = function(_, getFrame, scale)
            assert(scale.setting == Enum.EditModeUnitFrameSetting.FrameSize and scale.getFrame == getFrame)
            positioned[#positioned + 1] = getFrame()
            return { type = "group", inline = true, name = "Position and scale", order = 10, args = {} }
        end,
        GetNativeSettingScale = function(_, getFrame, setting)
            return { getFrame = getFrame, setting = setting }
        end,
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
    classIcon = {
        Refresh = function()
            counts.classIcons = counts.classIcons + 1
        end,
    },
    pvpIcon = {
        Refresh = function()
            counts.pvpIcons = counts.pvpIcons + 1
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
    if tab.args[key] then
        return tab.args[key]
    end
    for _, group in pairs(tab.args) do
        local found = group.args and find(group, key)
        if found then
            return found
        end
    end
end
assert(tabs.player.args.style.name == "Style" and tabs.player.args.position.name == "Position and scale")
for _, key in ipairs({ "target", "focus" }) do
    assert(tabs[key].args.style and tabs[key].args.position, key .. " has Position and scale")
end
assert(not tabs.pet.args.position and not tabs.party.args.position, "only frames with their own position")
assert(tabs.targettarget.args.position and tabs.targettarget.args.style, "the ToT frames are movable too")
assert(tabs.focustarget.args.position and find(tabs.targettarget, "targettarget_healthBarColor"))
assert(#positioned == 3 and positioned[1] == PlayerFrame and positioned[2] == TargetFrame)
assert(positioned[3] == FocusFrame, "each group resolves its own frame")
assert(tabs.player.args.style.args.player_classIcon.type == "toggle")
assert(tabs.player.args.style.args.player_hidePvPIcon.type == "toggle")
for _, option in pairs(tabs.player.args.style.args) do
    assert(option.type ~= "group", "single player settings need no redundant headers")
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
assert(not find(tabs.pet, "pet_nameDisplay") and not find(tabs.pet, "pet_classIcon"), "a pet is never a player")
assert(not find(tabs.pet, "pet_hidePvPIcon") and not find(tabs.targettarget, "targettarget_hidePvPIcon"))
find(tabs.player, "player_classIcon").set(nil, true)
assert(app.db.profile.unitFrames.player.classIcon == true and counts.classIcons == 1)
find(tabs.party, "party_hidePvPIcon").set(nil, true)
assert(app.db.profile.unitFrames.party.hidePvPIcon == true and counts.pvpIcons == 1)

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
assert(targetRows["targettarget.classIcon"].name == "Target of Target class icon")
assert(targetRows["target.hidePvPIcon"] and not targetRows["targettarget.hidePvPIcon"])
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
UnitIsPlayer = function(unit)
    return unit ~= "target"
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
assert(TargetFrame.name:GetText() == "Hogger", "NPCs keep their name")
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
enabled = true
names.player = { "Anna", "Weber" }
app.db.profile.unitFrames.party.nameDisplay = "first"
member.name:SetText("Bob-Smith")
hooked(member)
assert(member.name:GetText() == "Bob")
names.party1 = { "Carl" }
app.db.profile.unitFrames.party.nameDisplay = "last"
member.name:SetText("Carl")
hooked(member)
assert(member.name:GetText() == "Carl", "no surname keeps the first name")
print("PASS: name display")

local preview = { unit = "player", name = FontString("Anna Weber") }
app.db.profile.unitFrames.targettarget.nameDisplay = "last"
nameDisplay:ApplyPreview(preview, "targettarget")
assert(preview.name:GetText() == "Weber", "preview uses its ToT setting with the player's identity")
preview.name:SetText("Anna Weber")
app.db.profile.unitFrames.targettarget.nameDisplay = "full"
nameDisplay:ApplyPreview(preview, "targettarget")
assert(preview.name:GetText() == "Anna Weber", "full preview name survives a settings change")

-- Class icon: the class atlas on player characters' portraits, the portrait back when off.
local function Portrait()
    local portrait = {}
    portrait.SetAtlas = function(self, atlas)
        self.atlas = atlas
    end
    return portrait
end
UnitClass = function(unit)
    return "Mage", unit == "target" and "WARRIOR" or "MAGE"
end
GetClassAtlas = function(class)
    return "classicon-" .. class:lower()
end
local portraitResets = 0
SetPortraitTexture = function(portrait)
    portraitResets = portraitResets + 1
    portrait.atlas = nil
end
local replaceCVar = false
UnitFrame_ShouldReplacePortrait = function()
    return replaceCVar
end
enabled = true
PlayerFrame.portrait, TargetFrame.portrait = Portrait(), Portrait()
app.db.profile.unitFrames.player.classIcon = true
app.db.profile.unitFrames.target.classIcon = true
hooksecurefunc = function(name, fn)
    assert(name == "UnitFramePortrait_Update")
    hooked = fn
end
loadfile("SeamlessUnitframes/src/portrait/classicon.lua")("SeamlessUnitframes", app)
modules.ClassIcon:OnInitialize()
hooked(PlayerFrame)
assert(PlayerFrame.portrait.atlas == "classicon-mage")
hooked(TargetFrame)
assert(TargetFrame.portrait.atlas == nil, "NPCs keep their portrait")
app.db.profile.unitFrames.player.classIcon = false
modules.ClassIcon:Refresh()
assert(PlayerFrame.portrait.atlas == nil and portraitResets == 1, "portrait restored")
modules.ClassIcon:Refresh()
assert(portraitResets == 1, "only portraits we changed")
app.db.profile.unitFrames.player.classIcon = true
modules.ClassIcon:Refresh()
replaceCVar = true
app.db.profile.unitFrames.player.classIcon = false
modules.ClassIcon:Refresh()
assert(portraitResets == 1, "the client's own class icon setting stays")
print("PASS: class icon portraits")

preview.portrait = Portrait()
app.db.profile.unitFrames.targettarget.classIcon = true
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.atlas == "classicon-mage")
replaceCVar = false
app.db.profile.unitFrames.targettarget.classIcon = false
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.atlas == nil, "preview restores the portrait when its class icon is disabled")

-- PvP icon: transparent while hidden, the game's own alpha back when shown.
local function Icon()
    local icon = { alpha = 1 }
    icon.SetAlpha = function(self, alpha)
        self.alpha = alpha
    end
    return icon
end
local playerIcon, targetIcon, partyIcon = Icon(), Icon(), Icon()
PlayerFrame_GetPvPIndicatorElements = function()
    return { pvpIcon = playerIcon }
end
TargetFrame.GetPvPIndicatorElements = function()
    return { pvpIcon = targetIcon }
end
member.PartyMemberOverlay = { PVPIcon = partyIcon }
local legacyCircle = Icon()
app.legacyLayout = {
    PvPBackground = function(_, icon)
        return icon == playerIcon and legacyCircle or nil
    end,
}
app.db.profile.unitFrames.player.hidePvPIcon = true
app.db.profile.unitFrames.party.hidePvPIcon = true
app.db.profile.unitFrames.target.hidePvPIcon = false
loadfile("SeamlessUnitframes/src/pvpicon/pvpicon.lua")("SeamlessUnitframes", app)
modules.PvPIcon.RegisterEvent = function() end
modules.PvPIcon:OnEnable()
assert(playerIcon.alpha == 0 and partyIcon.alpha == 0 and targetIcon.alpha == 1)
assert(legacyCircle.alpha == 0, "the Legacy layout's circle hides with its icon")
app.db.profile.unitFrames.player.hidePvPIcon = false
modules.PvPIcon:Refresh()
assert(playerIcon.alpha == 1 and legacyCircle.alpha == 1)
enabled = false
modules.PvPIcon:OnDisable()
assert(partyIcon.alpha == 1, "disabled shows the icons again")
print("PASS: PvP icons")
