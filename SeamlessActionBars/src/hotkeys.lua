---@type string, SeamlessActionBars
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Short keybind labels, built from the binding key itself ("SHIFT-BUTTON4" -> "SM4") so they do
-- not depend on the client's language. Keys without a short form use the game's own
-- abbreviated key name. Gamepad bindings keep the client's label.

-- Binding key modifiers in the order the client writes them.
local modifiers = {
    ALT = L["Alt (short)"],
    CTRL = L["Ctrl (short)"],
    SHIFT = L["Shift (short)"],
    META = L["Meta (short)"],
}

local keys = {
    BACKSPACE = L["Backspace (short)"],
    CAPSLOCK = L["Caps Lock (short)"],
    DELETE = L["Delete (short)"],
    DOWN = L["Down Arrow (short)"],
    END = L["End (short)"],
    ENTER = L["Enter (short)"],
    ESCAPE = L["Escape (short)"],
    HOME = L["Home (short)"],
    INSERT = L["Insert (short)"],
    LEFT = L["Left Arrow (short)"],
    MOUSEWHEELDOWN = L["Mouse Wheel Down (short)"],
    MOUSEWHEELUP = L["Mouse Wheel Up (short)"],
    PAGEDOWN = L["Page Down (short)"],
    PAGEUP = L["Page Up (short)"],
    RIGHT = L["Right Arrow (short)"],
    SPACE = L["Space (short)"],
    TAB = L["Tab (short)"],
    UP = L["Up Arrow (short)"],
}

local numpad = {
    DECIMAL = ".",
    DIVIDE = "/",
    MINUS = "-",
    MULTIPLY = "*",
    PLUS = "+",
}

---@param key string a binding key such as "CTRL-SHIFT-NUMPAD5"
---@return string
function app.ShortKeyLabel(key)
    local prefix, base = "", key
    while true do
        -- "SHIFT--" binds Shift and the minus key: the rest is "-".
        local modifier, rest = base:match("^(%u+)%-(.+)$")
        if not (modifier and modifiers[modifier]) then
            break
        end
        prefix, base = prefix .. modifiers[modifier], rest
    end
    local label = keys[base]
    if not label then
        local button = base:match("^BUTTON(%d+)$")
        local pad = base:match("^NUMPAD(%w+)$")
        if button then
            label = L["Mouse Button %d (short)"]:format(tonumber(button))
        elseif pad then
            label = L["Num Pad %s (short)"]:format(numpad[pad] or pad)
        else
            label = GetBindingText(base, 1)
        end
    end
    return prefix .. label
end

-- The client's label of each hotkey we shortened, put back when the option is switched off.
---@type table<FontString, string>
local originals = setmetatable({}, { __mode = "k" })

---@param button CheckButton
function app.RestoreHotkey(button)
    local hotkey = button.HotKey
    local original = hotkey and originals[hotkey]
    if original then
        hotkey:SetText(original)
        originals[hotkey] = nil
    end
end

---@param button CheckButton
function app.UpdateHotkey(button)
    local hotkey = button.HotKey
    if not hotkey then
        return
    end
    if not app.db.profile.keybinds.enabled then
        app.RestoreHotkey(button)
        return
    end
    local text = hotkey:GetText()
    -- Unbound buttons show the range dot instead of a label.
    if not text or text == RANGE_INDICATOR then
        originals[hotkey] = nil
        return
    end
    -- The same lookup as `ActionBarActionButtonMixin:UpdateHotkeys`.
    local key = (button.bindingAction and GetBindingKey(button.bindingAction))
        or GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
    if not key or (IsBindingForGamePad and IsBindingForGamePad(key)) then
        return
    end
    local label = app.ShortKeyLabel(key)
    if text ~= label then
        originals[hotkey] = text
        hotkey:SetText(label)
    end
end
