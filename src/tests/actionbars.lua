-- Run from the repository root: lua src/tests/actionbars.lua
local root = "SeamlessActionBars/src/"

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
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local libStub = LibStub
local addon = {}
function addon:IsEnabled()
    return true
end
LibStub = function(major)
    if major == "AceLocale-3.0" then
        return libStub(major)
    end
    return {
        GetAddon = function()
            return {}
        end,
        NewAddon = function()
            return addon
        end,
    }
end

RANGE_INDICATOR = "●"
GetBindingText = function(key)
    return "game:" .. key
end
local bindings = {}
GetBindingKey = function(action)
    return bindings[action]
end
IsBindingForGamePad = function(key)
    return key:find("^PAD") ~= nil
end

-- Action slots: usable, lacking mana, range (nil = no range).
local slots = {}
C_ActionBar = {
    HasAction = function(action)
        return slots[action] ~= nil
    end,
    IsUsableAction = function(action)
        return slots[action].usable, slots[action].noMana
    end,
    IsActionInRange = function(action)
        return slots[action].inRange
    end,
}

local function Texture()
    local color = { 1, 1, 1 }
    return {
        SetVertexColor = function(_, r, g, b)
            color = { r, g, b }
        end,
        color = function()
            return color[1], color[2], color[3]
        end,
    }
end
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
local function Button(name, action, text)
    return {
        action = action,
        bindingAction = name,
        icon = Texture(),
        HotKey = FontString(text),
        GetName = function()
            return name
        end,
    }
end

local app = {}
app.BarHiddenOption = function(_, name, order)
    return { type = "toggle", name = name, order = order, default = false }
end
local function load(file)
    assert(loadfile(root .. file))("SeamlessActionBars", app)
end
load("icons.lua")
load("hotkeys.lua")
app.db = {
    profile = {
        range = { enabled = true, color = { r = 0.85, g = 0.4, b = 0.4 } },
        mana = { enabled = true, color = { r = 0.3, g = 0.3, b = 1 } },
        keybinds = { enabled = true },
    },
}

local function same(a, b, c, r, g, bl)
    return math.abs(a - r) < 1e-6 and math.abs(b - g) < 1e-6 and math.abs(c - bl) < 1e-6
end

-- Labels
assert(app.ShortKeyLabel("SHIFT-BUTTON4") == "SM4")
assert(app.ShortKeyLabel("CTRL-SHIFT-NUMPAD5") == "CSN5")
assert(app.ShortKeyLabel("NUMPADPLUS") == "N+")
assert(app.ShortKeyLabel("ALT-MOUSEWHEELUP") == "AWU")
assert(app.ShortKeyLabel("SHIFT--") == "Sgame:-")
assert(app.ShortKeyLabel("-") == "game:-")
assert(app.ShortKeyLabel("SPACE") == L["Space (short)"])
assert(app.ShortKeyLabel("Q") == "game:Q")

-- Icons: range before mana, native colors restored when a tint ends.
slots[1] = { usable = true, noMana = false, inRange = false }
local button = Button("ACTIONBUTTON1", 1, "s-M4")
app.PaintIcon(button)
assert(same(0.85, 0.4, 0.4, button.icon.color()), "out of range")
slots[1].inRange = true
app.PaintIcon(button)
assert(same(1, 1, 1, button.icon.color()), "back in range")
slots[1] = { usable = false, noMana = true }
app.PaintIcon(button)
assert(same(0.3, 0.3, 1, button.icon.color()), "no mana")
app.db.profile.mana.enabled = false
app.PaintIcon(button)
assert(same(0.5, 0.5, 1, button.icon.color()), "native mana shade")
app.db.profile.mana.enabled = true
app.PaintIcon(button)
app.RestoreIcon(button)
assert(same(0.5, 0.5, 1, button.icon.color()), "restore")
slots[1] = { usable = false, noMana = false, inRange = nil }
button.icon:SetVertexColor(0.4, 0.4, 0.4)
app.PaintIcon(button)
assert(same(0.4, 0.4, 0.4, button.icon.color()), "untinted unusable stays grey")

-- Hotkeys
bindings.ACTIONBUTTON1 = "SHIFT-BUTTON4"
app.UpdateHotkey(button)
assert(button.HotKey:GetText() == "SM4")
app.UpdateHotkey(button)
assert(button.HotKey:GetText() == "SM4", "idempotent")
app.db.profile.keybinds.enabled = false
app.UpdateHotkey(button)
assert(button.HotKey:GetText() == "s-M4", "restored")
app.db.profile.keybinds.enabled = true
local unbound = Button("ACTIONBUTTON2", 2, RANGE_INDICATOR)
app.UpdateHotkey(unbound)
assert(unbound.HotKey:GetText() == RANGE_INDICATOR)
bindings.ACTIONBUTTON3 = "PADDUP"
local pad = Button("ACTIONBUTTON3", 3, "pad")
app.UpdateHotkey(pad)
assert(pad.HotKey:GetText() == "pad", "gamepad untouched")
local clicked = Button("MultiBar5Button1", 4, "x")
clicked.bindingAction = "MULTIACTIONBAR5BUTTON1"
bindings["CLICK MultiBar5Button1:LeftButton"] = "CTRL-E"
app.UpdateHotkey(clicked)
assert(clicked.HotKey:GetText() == "Cgame:E", "click binding")

-- Endcaps: profile scale through the frame's own SetScale, native Hidden through Core's service.
local combat = false
InCombatLockdown = function()
    return combat
end
local function EndCap(index)
    local cap = { scale = 1, system = 26, systemIndex = index, scaleCalls = 0 }
    function cap:GetScale()
        return self.scale
    end
    function cap:SetScale(value)
        self.scale, self.scaleCalls = value, self.scaleCalls + 1
    end
    return cap
end
local left, right = EndCap(1), EndCap(2)
MainActionBar = { EndCaps = { LeftEndCap = left, RightEndCap = right } }
Enum = {
    EditModeSystem = { MainActionBarEndCap = 26 },
    EditModeMainActionBarEndCapSystemIndices = { EndCapLeft = 1, EndCapRight = 2 },
    EditModeMainActionBarEndCapSetting = { Hidden = 0 },
}
local hidden, canEdit, refreshed, registered = { [left] = 0, [right] = 0 }, true, 0, {}
local service = {
    ReadSetting = function(_, frame, setting)
        assert(setting == 0)
        return frame and hidden[frame]
    end,
    ApplySetting = function(_, frame, setting, value)
        assert(setting == 0 and canEdit)
        hidden[frame] = value
        return true
    end,
    CanEdit = function()
        return canEdit
    end,
    GetDefaultSetting = function()
        return 0
    end,
}
app.core = {
    GetFramePositionService = function()
        return service
    end,
    RefreshOptions = function()
        refreshed = refreshed + 1
    end,
    RegisterEditModeSystemScale = function(_, id, spec)
        registered[id] = spec
    end,
}
local enabled = true
function addon:IsEnabled()
    return enabled
end
app.addon = addon
app.dbDefaults = { profile = { endCaps = { left = { scale = 1 }, right = { scale = 1 } } } }
app.db.profile.endCaps = { left = { scale = 1.5 }, right = { scale = 1 } }
load("endcaps.lua")
app.ApplyEndCapScales()
assert(left.scale == 1.5 and right.scale == 1 and right.scaleCalls == 0, "profile scale applied, unchanged left alone")
local leftEntry = app.endCaps[1]
local scale = app.EndCapScale(leftEntry)
assert(scale.get() == 1.5 and scale.default() == 1 and scale.min == 0.5 and scale.max == 2)
scale.set(0.8)
assert(app.db.profile.endCaps.left.scale == 0.8 and left.scale == 0.8 and refreshed == 1)
combat = true
scale.set(1.2)
assert(app.db.profile.endCaps.left.scale == 1.2 and left.scale == 0.8, "no SetScale in combat")
combat = false
app.ApplyEndCapScales()
assert(left.scale == 1.2, "applied after combat")
enabled = false
scale.set(1.4)
assert(app.db.profile.endCaps.left.scale == 1.4 and left.scale == 1.2, "disabled addon only stores")
app.ApplyEndCapScales(true)
assert(left.scale == 1 and right.scale == 1, "disable restores the game's scale")
enabled = true
app.RegisterEndCapScales()
local spec = registered["SeamlessActionBars:endCap:left"]
assert(spec and spec.system == 26 and spec.systemIndex == 1 and spec.enabled())
assert(registered["SeamlessActionBars:endCap:right"].systemIndex == 2)
local toggle = app.EndCapHiddenOption(app.endCaps[2])
assert(toggle.type == "toggle" and toggle.layoutStored and not toggle.editMode and toggle.name == L["Hide endcap"])
assert(toggle.get() == false and toggle.default() == false and not toggle.disabled())
toggle.set(nil, true)
assert(hidden[right] == 1 and toggle.get() == true and hidden[left] == 0)
toggle.set(nil, false)
assert(hidden[right] == 0)
canEdit = false
assert(toggle.disabled(), "preset layouts are read-only")
canEdit = true
MainActionBar = nil
assert(toggle.disabled() and app.EndCapFrame(leftEntry) == nil, "missing bar is safe")
app.ApplyEndCapScales()

-- Micro menu: layout settings use the native service; artwork follows the current profile.
local microModule = { enabled = true }
function microModule:IsEnabled()
    return self.enabled
end
function microModule:RegisterEvent() end
function microModule:UnregisterAllEvents() end
function addon:NewModule()
    return microModule
end
Enum.EditModeMicroMenuSetting = { Orientation = 0, Order = 1, Size = 2 }
Enum.EditModeSystem.MicroMenu = 20
Enum.MicroMenuOrientation = { Horizontal = 0, Vertical = 1 }
Enum.MicroMenuOrder = { Default = 0, Reverse = 1 }
MicroMenuContainer = {}
local native = { [0] = 0, [1] = 0, [2] = 100 }
function service:ReadSetting(frame, setting)
    return frame and native[setting]
end
function service:ApplySetting(frame, setting, value)
    assert(frame == MicroMenuContainer and canEdit)
    native[setting] = value
    return true
end
function service:GetDefaultSetting(_, setting)
    return setting == 2 and 100 or 0
end
function app.core:GetNativeSettingScale(getFrame, setting)
    return {
        min = 0.7,
        max = 2,
        step = 0.05,
        get = function()
            return service:ReadSetting(getFrame(), setting) / 100
        end,
        set = function(value)
            service:ApplySetting(getFrame(), setting, value * 100)
        end,
        default = function()
            return 1
        end,
        disabled = function()
            return not getFrame()
        end,
    }
end
local function Art(alpha)
    return {
        alpha = alpha,
        GetAlpha = function(self)
            return self.alpha
        end,
        SetAlpha = function(self, value)
            self.alpha = value
        end,
    }
end
MicroMenu = { BorderArt = Art(0.8), BackgroundArt = Art(1), button = Art(1) }
app.db.profile.microMenu = { hideArtwork = false }
load("micromenu.lua")
local menuSpec
function app.core:RegisterEditModeSystemOptions(_, value)
    menuSpec = value
end
function app.core:RefreshEditModeSystemOptions() end
microModule:OnInitialize()
assert(menuSpec.name == L["Style"] and menuSpec.system == 20 and #menuSpec.options == 4)
local group = app.MicroMenuOptions()
assert(group.name == L["Style"])
local menu = group.args
assert(menu.orientation.get() == 0 and menu.order.default() == 0)
assert(menu.size == nil, "size is only exposed through Position and scale")
menu.orientation.set(nil, 1)
menu.order.set(nil, 1)
assert(native[0] == 1 and native[1] == 1 and native[2] == 100)
menuSpec.options[1].set(0)
assert(menu.orientation.get() == 0 and menuSpec.options[1].values[1].value == 0)
menuSpec.options[2].set(0)
assert(menu.order.get() == 0)
canEdit = false
assert(menu.orientation.disabled() and menu.order.disabled() and menuSpec.options[1].disabled())
canEdit = true
menuSpec.options[3].set(true)
app.RefreshMicroMenu()
assert(MicroMenu.BorderArt.alpha == 0 and MicroMenu.BackgroundArt.alpha == 0 and MicroMenu.button.alpha == 1)
app.db.profile = { microMenu = { hideArtwork = false } }
app.RefreshMicroMenu()
assert(MicroMenu.BorderArt.alpha == 0.8 and MicroMenu.BackgroundArt.alpha == 1, "profile change restores art")
menu.hideArtwork.set(nil, true)
microModule:OnDisable()
assert(MicroMenu.BorderArt.alpha == 0.8 and MicroMenu.BackgroundArt.alpha == 1, "disable restores original alpha")
MicroMenu = nil
app.RefreshMicroMenu()
MicroMenuContainer = nil
assert(menu.orientation.get() == nil, "missing native frame is safe")

-- Bags resolve the live frame and use native layout settings, including orientation-dependent direction.
Enum.EditModeBagsSetting = { Orientation = 0, Direction = 1, Size = 2, BagSlotPadding = 3 }
Enum.BagsOrientation = { Horizontal = 0, Vertical = 1 }
Enum.BagsDirection = { Left = 0, Right = 1, Up = 0, Down = 1 }
BagsBar = {}
native = { [0] = 0, [1] = 0, [2] = 100, [3] = 4 }
function service:ApplySetting(frame, setting, value)
    assert(frame == BagsBar and canEdit)
    native[setting] = value
    return true
end
function app.core:GetNativePositionOptions(getFrame, scale)
    return { getFrame = getFrame, scale = scale }
end
function app.core:GetEditModePositionButton(key)
    return { name = key }
end
function app.core:GetEditModeButtonSection(buttons)
    return { options = buttons }
end
app.optionPages = {}
assert(loadfile(root .. "options/bags.lua"))("SeamlessActionBars", app)
local bags = app.optionPages.bags.config
local bagStyle = bags.args.layout.args
Enum.EditModeSystem.Bags = 21
load("bags.lua")
microModule:OnInitialize()
local bagSpec = menuSpec
assert(bagSpec.name == L["Style"] and bagSpec.system == 21 and #bagSpec.options == 6)
local showFreeSlots = false
GetCVarBool = function(name)
    assert(name == "displayFreeBagSlots")
    return showFreeSlots
end
SetCVar = function(name, value)
    assert(name == "displayFreeBagSlots")
    showFreeSlots = value
end
assert(not bagStyle.freeSlots.get() and not bagStyle.freeSlots.blizzard and not bagStyle.freeSlots.editMode)
bagSpec.options[5].set(true)
assert(bagStyle.freeSlots.get(), "the native CVar is shared by config and Edit Mode")
app.db.profile.bags = { retailStyle = false, spacing = 4 }
app.RefreshBagStyle = function() end
InCombatLockdown = function()
    return false
end
assert(bagStyle.spacing.disabled() and bagStyle.spacing.default == 0)
app.db.profile.bags.retailStyle = true
assert(not bagStyle.spacing.disabled())
bagSpec.options[4].set(8)
assert(bagStyle.spacing.get() == 8 and bagSpec.options[4].get() == 8)
assert(bagSpec.options[2].values()[1].text == L["Left"])
assert(bags.editModeFrame() == BagsBar and not bags.hidden())
assert(bagStyle.direction.values()[0] == L["Left"])
bagStyle.orientation.set(nil, 1)
assert(bagSpec.options[2].values()[1].text == L["Up"])
assert(bagStyle.direction.values()[0] == L["Up"] and bagStyle.direction.values()[1] == L["Down"])
bagStyle.direction.set(nil, 1)
bags.args.position.scale.set(1.25)
assert(native[0] == 1 and native[1] == 1 and native[2] == 125 and native[3] == 4)
assert(bagStyle.padding == nil, "unsupported slot spacing is not exposed")
assert(bagStyle.size == nil, "size is only exposed through Position and scale")
canEdit = false
assert(bagStyle.orientation.disabled() and bagStyle.direction.disabled())
canEdit = true
BagsBar = nil
assert(bags.hidden() and bagStyle.direction.disabled() and bagStyle.orientation.get() == nil)

print("PASS: short labels, range/mana tints, native restore, hotkey restore, endcaps, micro menu and bags")
