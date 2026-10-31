unpack = unpack or table.unpack
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

local cvars = { threatShowNumeric = "0", statusTextDisplay = "NONE", statusText = "0" }
GetCVar = function(name)
    return cvars[name]
end
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
Enum = { EditModeUnitFrameSetting = { FrameSize = 9 }, EditModeAccountSetting = { ShowPetFrame = 24 } }
local modules = {}
local app = {
    db = {
        char = { nameOverride = "" },
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
                return { type = "group", inline = true, name = "Position", order = 10, args = {} }, {
                    type = "group",
                    name = "Size",
                    order = 11,
                    args = {},
                }
            end
        end,
    },
    core = {
        GetNativePositionOptions = function(_, getFrame, scale)
            assert(scale.setting == Enum.EditModeUnitFrameSetting.FrameSize and scale.getFrame == getFrame)
            positioned[#positioned + 1] = getFrame()
            return { type = "group", inline = true, name = "Position", order = 10, args = {}, editModePosition = {} }, {
                type = "group",
                name = "Size",
                order = 11,
                args = {},
                editModeSize = true,
            }
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
app.optionPages, app.dbDefaults = {}, {}
local coreApp = { addon = app.core, config = {} }
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", coreApp)
app.core.GetEditModeButtonSection = dofile("src/tests/settings-support.lua").buttonSection
app.core.GetEditModePositionButton = dofile("src/tests/settings-support.lua").positionButton
local petVisibilityUpdate
app.core.GetCustomEditModeVisibility = dofile("src/tests/settings-support.lua").customVisibility
function app.core:GetEditModeVisibility(setting, update)
    assert(type(update) == "function")
    petVisibilityUpdate = update
    return function(value)
        return self:EditModeVisibility(setting, value)
    end
end
dofile("src/tests/settings-support.lua").pages("SeamlessUnitframes", app)
dofile("src/tests/settings-support.lua").defaults("SeamlessUnitframes", app)
dofile("src/tests/settings-support.lua").editModePages(app.core, "SeamlessUnitframes", app)
-- The rows Core draws in Edit Mode for a page, keyed by their option's key.
local function pageRows(key)
    local byKey, list = {}, {}
    for _, section in ipairs(app.core:GetEditModePageSections("SeamlessUnitframes", key)) do
        for _, row in ipairs(section.options) do
            list[#list + 1] = row
            byKey[row.setting.path[#row.setting.path]] = row
        end
    end
    return byKey, list
end
load("editmode.lua")

-- Options: every unit frame exposes the shared layout in its Style section.
modules.Options.RegisterEvent = function() end
modules.Options:OnInitialize()
local tabs = {}
for key, page in pairs(registeredOptions.pages) do
    tabs[key] = page.config
end
assert(not registeredOptions.pages.general, "no General page")
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
assert(tabs.player.args.style.name == "Style" and tabs.player.args.position.name == "Position")
for _, key in ipairs({ "pet", "target", "focus" }) do
    assert(tabs[key].args.style and tabs[key].args.position, key .. " has Position")
end
assert(not tabs.party.args.position, "only frames with their own position")
assert(tabs.targettarget.args.position and tabs.targettarget.args.style, "the ToT frames are movable too")
assert(tabs.focustarget.args.position and find(tabs.targettarget, "targettarget_healthBarColor"))
assert(#positioned == 4 and positioned[1] == PlayerFrame and positioned[2] == PetFrame)
assert(positioned[3] == TargetFrame and positioned[4] == FocusFrame, "each group resolves its own frame")
local layoutRefreshes = 0
app.legacyLayout = {
    Refresh = function()
        layoutRefreshes = layoutRefreshes + 1
    end,
}
for key, tab in pairs(tabs) do
    local option = tab.args.style.args.layout
    assert(option and option.type == "select", key .. " has the shared layout")
    assert(option.values.legacyRounded == "Beta (rounded)")
    option.set(nil, "legacyRounded")
    for _, other in pairs(tabs) do
        assert(other.args.style.args.layout.get() == "legacyRounded", "all selectors share the layout")
    end
    assert(app.optionPages[key].tooltip({ key, "style", "layout" }) == "current")
    local _, rows = pageRows(key)
    assert(rows[1].setting.path[3] == "layout" and rows[1].default() == "current")
    if rows[1].hidden() then
        -- A page whose frame does not exist is hidden, and so are its rows; they never write.
        rows[1].set("current")
        assert(option.get() == "legacyRounded")
        option.set(nil, "current")
    else
        rows[1].set("current")
    end
    assert(option.get() == "current", "Edit Mode updates the same setting")
end
-- Writes from Edit Mode also refresh the settings pages, like the settings window's own (6 rows).
assert(layoutRefreshes == 14 and counts.optionRefreshes == 20 and counts.systemRefreshes == 14)
local levelRefreshes = 0
app.levelDisplay = {
    Refresh = function()
        levelRefreshes = levelRefreshes + 1
    end,
}
for _, key in ipairs({ "player", "target", "focus" }) do
    local option = find(tabs[key], key .. "_levelDisplay")
    assert(option.type == "select" and #option.sorting == 3)
    assert(app.optionPages[key].defaults.profile.unitFrames[key].levelDisplay == "default")
    option.set(nil, "smaller")
    assert(option.get() == "smaller" and app.db.profile.unitFrames[key].levelDisplay == "smaller")
end
assert(levelRefreshes == 3)
assert(not find(tabs.pet, "pet_levelDisplay") and not find(tabs.party, "party_levelDisplay"))
-- Every page wraps the same native setting, including both CVars and live external changes.
for _, key in ipairs({ "player", "pet", "target", "focus", "targettarget", "focustarget", "party" }) do
    local option = find(tabs[key], "statusText")
    assert(option.type == "select" and option.blizzard and option.default == "NONE")
    assert(table.concat(option.sorting, ",") == "NUMERIC,PERCENT,BOTH,NONE")
    for _, value in ipairs(option.sorting) do
        option.set(nil, value)
        assert(cvars.statusTextDisplay == value and cvars.statusText == (value == "NONE" and "0" or "1"))
        assert(find(tabs.player, "statusText").get() == value)
        assert(find(tabs.target, "statusText").get() == value)
    end
    cvars.statusTextDisplay = "PERCENT"
    assert(option.get() == "PERCENT", "read external CVar changes live")
    assert(app.db.profile.unitFrames[key].statusText == nil, "no profile copy of the CVar")
end
-- Keep the pre-existing refresh-count assertions below independent of these controls.
counts.optionRefreshes, counts.systemRefreshes = 0, 0
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
print("PASS: one options tab per unit frame, shared layout in Style")

-- Player-only choices and a character-scoped input below the name dropdown.
local playerName = find(tabs.player, "player_nameDisplay")
local customName = find(tabs.player, "player_nameOverride")
assert(playerName.values.combine == "Combine" and playerName.values.override == "Override")
assert(not partyName.values.combine and not partyName.values.override)
assert(customName.hidden() and customName.order > playerName.order)
playerName.set(nil, "override")
assert(not customName.hidden())
customName.set(nil, "My Hero")
assert(app.db.char.nameOverride == "My Hero" and not app.db.profile.unitFrames.player.nameOverride)
local originalChar = app.db.char
app.db.char = { nameOverride = "Other Hero" }
assert(customName.get() == "Other Hero", "input resolves the current character")
app.db.char = originalChar
playerName.set(nil, "full")
assert(customName.hidden())

-- Edit Mode: each frame owns its Style options.
Enum = {
    EditModeSystem = { UnitFrame = 0 },
    EditModeUnitFrameSystemIndices = { Player = 1, Target = 2, Focus = 3, Party = 4, Pet = 7 },
}
modules.EditMode:OnEnable()
modules.EditMode:OnEnable()
local function rows(id)
    local spec = systemOptions["SeamlessUnitframes." .. id]
    assert(spec and spec.system == 0 and spec.page.key == id, id)
    return spec, (pageRows(id))
end
local playerSpec, playerRows = rows("player")
assert(playerSpec.systemIndex == 1 and playerSpec.enabled())
assert(not systemOptions["SeamlessUnitframes.targettarget"], "no section without a system")
local targetSpec, targetRows = rows("target")
assert(targetSpec.systemIndex == 2)
assert(not targetRows.targettarget_healthBarColor, "ToT style is not linked to Target")
assert(targetRows.target_nameDisplay.name == "Name display")
assert(targetRows.threatPercentage and targetRows.questIcon_x)
local _, focusRows = rows("focus")
assert(not focusRows.focustarget_healthBarColor, "focus ToT style is not linked to Focus")
local childRows = pageRows("targettarget")
assert(childRows.targettarget_healthBarColor.name == "Health bar color")
assert(childRows.targettarget_classIcon.name == "Class icon")
local _, petRows = rows("pet")
assert(rows("party") and petRows.pet_healthBarColor.values()[1].value == "default")

childRows.targettarget_healthBarColor.set("default")
assert(app.db.profile.unitFrames.targettarget.healthBarColor == "default")
assert(find(tabs.targettarget, "targettarget_healthBarColor").get() == "default", "same profile as the tab")
playerRows.player_healthBarColor.set("class")
assert(playerColor.get() == "class")
assert(targetRows.questIcon_scale.format(2.3) == "2.3")
enabled = false
assert(not playerSpec.enabled(), "the section leaves while the addon is disabled")
childRows.targettarget_nameDisplay.set("last")
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
app.db.profile.unitFrames.player.nameDisplay = "combine"
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "AnnaWeber", "combined names have no separator")
names.player = { "Anna-Weber" }
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "AnnaWeber", "combined regional name")
names.player = { "Anna" }
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "Anna", "combine without surname")
names.player = { "Anna", "Weber" }
app.db.profile.unitFrames.player.nameDisplay = "override"
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "My Hero")
PlayerFrame.name:SetText("Anna Weber")
hooked(PlayerFrame)
assert(PlayerFrame.name:GetText() == "My Hero", "native updates preserve the override")
app.db.char = { nameOverride = "Other Hero" }
nameDisplay:OnProfileRefresh()
assert(PlayerFrame.name:GetText() == "Other Hero", "reads current character storage")
app.db.char.nameOverride = ""
nameDisplay:Refresh()
assert(PlayerFrame.name:GetText() == "Anna Weber", "empty override restores native name")
app.db.char.nameOverride = "My Hero"
nameDisplay:Refresh()
enabled = false
nameDisplay:OnDisable()
assert(PlayerFrame.name:GetText() == "Anna Weber", "disable restores override")
enabled = true
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
    local portrait = { SetTexCoord = function() end }
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

-- VIP identity is painted only through the custom-preview entry points.
preview.portrait = Portrait()
local character = { name = "VIP", surname = "Supporter", class = "PALADIN" }
app.previewCharacters = {
    Get = function()
        return character
    end,
}
app.db.profile.unitFrames.targettarget.nameDisplay = "full"
nameDisplay:ApplyPreview(preview, "targettarget")
assert(preview.name:GetText() == "VIP-Supporter")
app.db.profile.unitFrames.targettarget.nameDisplay = "last"
nameDisplay:ApplyPreview(preview, "targettarget")
assert(preview.name:GetText() == "Supporter")
app.db.profile.unitFrames.targettarget.classIcon = true
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.atlas == "classicon-paladin")
character.displayTexture = "existing-portrait"
preview.portrait.SetTexture = function(self, value)
    self.texture = value
end
preview.portrait.SetTexCoord = function(self, ...)
    self.coords = { ... }
end
app.db.profile.unitFrames.targettarget.classIcon = false
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.texture == "existing-portrait" and preview.portrait.coords[2] == 1)
app.db.profile.unitFrames.targettarget.classIcon = true
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.atlas == "classicon-paladin", "class icon preference wins over custom portrait")
character.class, character.displayTexture = nil, nil
preview.portrait.atlas = "live-fallback"
modules.ClassIcon:ApplyPreview(preview, "targettarget")
assert(preview.portrait.atlas == "live-fallback", "missing portrait/class retains the existing fallback")
app.previewCharacters = {
    Get = function()
        return nil -- Outside Edit Mode, the controller leaves native cosmetics alone.
    end,
}
nameDisplay:Refresh()
modules.ClassIcon:Refresh()
app.previewCharacters = nil
print("PASS: VIP names and portrait preferences")

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

-- Target/focus name backgrounds are independent and restore after profile changes or disable.
local targetBackground, focusBackground = Icon(), Icon()
local backgroundHookCount = 0
hooksecurefunc = function(object, method, callback)
    backgroundHookCount = backgroundHookCount + 1
    local original = object[method]
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
for _, background in ipairs({ targetBackground, focusBackground }) do
    background.SetVertexColor = function(self, r, g, b, alpha)
        self.alpha = alpha
    end
end
TargetFrame.TargetFrameContent = { TargetFrameContentMain = { ReputationColor = targetBackground } }
FocusFrame.TargetFrameContent = { TargetFrameContentMain = { ReputationColor = focusBackground } }
loadfile("SeamlessUnitframes/src/name/namebackground.lua")("SeamlessUnitframes", app)
modules.NameBackground.RegisterEvent = function() end
enabled = true
for _, key in ipairs({ "target", "focus" }) do
    assert(app.optionPages[key].defaults.profile.unitFrames[key].hideNameBackground == false)
    local option = find(tabs[key], key .. "_hideNameBackground")
    assert(option.type == "toggle")
    option.set(nil, true)
    assert(option.get() == true)
end
modules.NameBackground:OnEnable()
assert(targetBackground.alpha == 0 and focusBackground.alpha == 0)
targetBackground:SetAlpha(1)
focusBackground:SetVertexColor(1, 0, 0, 1)
assert(targetBackground.alpha == 0 and focusBackground.alpha == 0, "retarget/reaction updates keep backgrounds hidden")
modules.NameBackground:Refresh()
assert(backgroundHookCount == 4, "refresh does not duplicate texture hooks")
app.db.profile.unitFrames.target = { hideNameBackground = false }
modules.NameBackground:OnProfileRefresh()
assert(targetBackground.alpha == 1 and focusBackground.alpha == 0)
targetBackground:SetAlpha(0.5)
assert(targetBackground.alpha == 0.5, "visible backgrounds retain native opacity changes")
enabled = false
modules.NameBackground:OnDisable()
assert(focusBackground.alpha == 1)
focusBackground:SetVertexColor(0, 1, 0, 0.5)
assert(focusBackground.alpha == 0.5, "disabled module leaves native updates alone")
print("PASS: name backgrounds")

-- The Pet declaration delegates to the shared account-visibility service.
Enum.EditModeAccountSetting = { ShowPetFrame = 24 }
local choice = false
function app.core:EditModeVisibility(setting, value)
    assert(setting == 24)
    if value ~= nil then
        choice = value
    end
    return choice
end
local visibility = app.optionPages.pet.config.editModeVisibility
assert(not visibility())
assert(visibility(true) and visibility())
assert(not visibility(false) and not visibility())
print("PASS: Pet header delegates visibility to Core")
local petChecked, petRefreshes = nil, 0
EditModeManagerFrame = {
    AccountSettings = {
        SetPetFrameShown = function(_, value, userInput)
            assert(userInput == false, "Never rebuild the shared account-setting map")
            petChecked = value
        end,
        RefreshPetFrame = function()
            petRefreshes = petRefreshes + 1
        end,
    },
}
petVisibilityUpdate(true)
assert(petChecked and petRefreshes == 1)
petVisibilityUpdate(false)
assert(not petChecked and petRefreshes == 2)
