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

print("PASS: short labels, range/mana tints, native restore and hotkey restore")
