---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Read declared defaults without touching live profiles. Honor AceDB wildcard defaults.
function app.addon:GetOptionDefault(defaults, path, first)
    local function read(value, index)
        if index > #path then
            return value
        end
        if type(value) ~= "table" then
            return nil
        end
        local nextValue = value[path[index]]
        if nextValue == nil then
            nextValue = value["*"]
        end
        if nextValue == nil then
            nextValue = value["**"]
        end
        local result = read(nextValue, index + 1)
        if result == nil and value["**"] ~= nil and nextValue ~= value["**"] then
            return read(value["**"], index + 1)
        end
        return result
    end
    return read(defaults, first or 1)
end

function app.addon:GetCVarOptionInfo(name)
    local _, default, _, character = C_CVar.GetCVarInfo(name)
    if default == "0" then
        return false, character, true
    end
    if default == "1" then
        return true, character, true
    end
    return default, character, true
end

-- Compatibility with existing option declarations is data-only. The custom
-- window never creates AceGUI widgets or asks AceConfigDialog to render a page.
local Option = {}
app.config.Option = Option
local inherited =
    { get = true, set = true, func = true, hidden = true, disabled = true, confirm = true, validate = true }
local methods = {
    get = true,
    set = true,
    func = true,
    values = true,
    disabled = true,
    hidden = true,
    validate = true,
    confirm = true,
}

function Option:New(root, path, name)
    return setmetatable({ root = root, path = path, appName = name }, { __index = self })
end

function app.addon:GetSettingsOption(root, path, name)
    return Option:New(root, path, name)
end

-- One tooltip for every setting row, in the config window and in Edit Mode: name, description,
-- then for settings the default line and storage markers. Bottom-left corner on the top-right of
-- the anchor (the row's name), padded 12 pixels right and 8 up, never following the cursor.
---@param owner table
---@param anchor table
---@param name string?
---@param desc string?
---@param details { default: string, perCharacter: boolean?, blizzardCVar: boolean?, layoutStored: boolean? }?
function app.addon:ShowSettingTooltip(owner, anchor, name, desc, details)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 12, 8)
    GameTooltip:SetText(name or "", 1, 1, 1)
    if desc and desc ~= "" then
        GameTooltip:AddLine(desc, nil, nil, nil, true)
    end
    if details then
        GameTooltip:AddLine(string.format(L["\n(Default: |cff8080ff%s|r)"], details.default), nil, nil, nil, true)
        if details.perCharacter then
            GameTooltip:AddLine(L["|cff8080ff[Per-character setting]|r"], nil, nil, nil, true)
        end
        if details.blizzardCVar then
            GameTooltip:AddLine(L["|cff8080ff[Blizzard CVAR]|r"], nil, nil, nil, true)
        end
        if details.layoutStored then
            GameTooltip:AddLine(L["|cff8080ff[Saved in the Edit Mode layout]|r"], nil, nil, nil, true)
        end
    end
    GameTooltip:Show()
end

---The refusal of a typed or chosen value, in the setting tooltip's place.
---@param owner table
---@param anchor table
---@param message string?
function app.addon:ShowSettingError(owner, anchor, message)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 12, 8)
    GameTooltip:SetText(message or L["Invalid value"], 1, 0.2, 0.2)
    GameTooltip:Show()
end

-- The declared default: the option's own `default` wins over the page's tooltip resolver.
-- Returns the value, then the per-character and Blizzard CVar markers.
function Option:DefaultValue()
    local resolver = app.config.optionInfo and app.config.optionInfo[self.appName]
    local value, perCharacter, blizzardCVar = self:Read("default"), nil, nil
    if type(value) == "function" then
        value, perCharacter, blizzardCVar = value()
    end
    if resolver then
        local resolved, resolvedPerCharacter, resolvedCVar = resolver(self.path)
        perCharacter = perCharacter or resolvedPerCharacter
        blizzardCVar = blizzardCVar or resolvedCVar
        if value == nil then
            value = resolved
        end
    end
    return value, perCharacter, blizzardCVar
end

function Option:TooltipDetails()
    local value, perCharacter, blizzardCVar = self:DefaultValue()
    if value == nil then
        return L["Not applicable"], perCharacter, blizzardCVar
    end
    if type(value) == "boolean" then
        return value and L["Enabled"] or L["Disabled"], perCharacter, blizzardCVar
    end
    if self:Read("type") == "select" then
        for _, choice in ipairs(self:Choices()) do
            if choice.value == value then
                return choice.text, perCharacter, blizzardCVar
            end
        end
    end
    if type(value) == "table" then
        local r, g, b, a = value.r or value[1], value.g or value[2], value.b or value[3], value.a or value[4] or 1
        if r and g and b then
            return string.format(
                "#%02X%02X%02X%02X",
                math.floor(r * 255 + 0.5),
                math.floor(g * 255 + 0.5),
                math.floor(b * 255 + 0.5),
                math.floor(a * 255 + 0.5)
            ),
                perCharacter,
                blizzardCVar
        end
        return L["Not applicable"], perCharacter, blizzardCVar
    end
    return value == "" and L["None"] or tostring(value), perCharacter, blizzardCVar
end

local SETTING_TOOLTIP_EXCLUDED = { group = true, header = true, description = true }

---The option's tooltip, the same in both windows; nothing for a group or text without a description.
---@param owner table
---@param anchor table
function Option:ShowTooltip(owner, anchor)
    local desc = self:Read("desc")
    local setting = not SETTING_TOOLTIP_EXCLUDED[self:Read("type")]
    if not setting and not (desc and desc ~= "") then
        return
    end
    local details
    if setting then
        local default, perCharacter, blizzardCVar = self:TooltipDetails()
        details = {
            default = default,
            perCharacter = perCharacter,
            blizzardCVar = blizzardCVar,
            layoutStored = self:InEditModeLayout(),
        }
    end
    app.addon:ShowSettingTooltip(owner, anchor, self:Read("name"), desc, details)
end

local CONFIRM = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, callback)
        callback()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

---Write values without validation or confirmation (a reset or a revert), unless the option is
---hidden or disabled now. Refreshes the addon's settings pages.
---@return boolean applied
function Option:Apply(...)
    if self:Read("hidden") or self:Read("disabled") then
        return false
    end
    self:Read(self:Read("type") == "execute" and "func" or "set", ...)
    app.config:NotifyChange(self.appName)
    return true
end

---Write values the player chose: `validate`, then `confirm` (the shared dialog), then Apply.
---@return boolean accepted False when validation refused the values.
---@return string? message Why they were refused.
function Option:Commit(...)
    local count, values = select("#", ...), { ... }
    local valid = self:Read("validate", ...)
    if valid == false or type(valid) == "string" then
        return false, type(valid) == "string" and valid or L["Invalid value"]
    end
    local confirm = self:Read("confirm", ...)
    if confirm then
        local message = type(confirm) == "string" and confirm or self:Read("confirmText") or L["Apply this change?"]
        StaticPopupDialogs.SeamlessConfigConfirm = StaticPopupDialogs.SeamlessConfigConfirm or CONFIRM
        StaticPopup_Show("SeamlessConfigConfirm", message, nil, function()
            -- Applies only if still enabled, as a profile may have changed meanwhile.
            self:Apply(unpack(values, 1, count))
        end)
    else
        self:Apply(...)
    end
    return true
end

---Put the declared default back, without confirmation. False when there is none.
---@return boolean
function Option:Reset()
    local kind = self:Read("type")
    local value = self:DefaultValue()
    if value == nil or kind == "execute" or kind == "group" or kind == "header" or kind == "description" then
        return false
    end
    if kind == "color" then
        if type(value) ~= "table" then
            return false
        end
        return self:Apply(value.r or value[1], value.g or value[2], value.b or value[3], value.a or value[4] or 1)
    end
    return self:Apply(value)
end

---A range value clamped to min/max and snapped to the step from min.
---@param value number
---@return number
function Option:Snap(value)
    local min, max, step = self:Read("min"), self:Read("max"), self:Read("step") or 1
    value = math.max(min, math.min(max, value))
    if step > 0 then
        value = min + math.floor((value - min) / step + 0.5) * step
    end
    return math.max(min, math.min(max, tonumber(string.format("%.12g", value))))
end

---A typed range value: a finite number within min/max, snapped; nil when it is not one.
---@param text string|number
---@return number?
function Option:ParseRange(text)
    local value = tonumber(text)
    local min, max = self:Read("min"), self:Read("max")
    if not value or value ~= value or value == math.huge or value == -math.huge or value < min or value > max then
        return nil
    end
    return self:Snap(value)
end

---A range value as both windows show it: as many decimals as the step and min need.
---@param value number
---@return string
function Option:FormatRange(value)
    local step = self:Read("step") or 1
    if step <= 0 then
        return string.format("%.12g", value)
    end
    local function decimals(number)
        return #string.format("%.8f", number):match("%.(.-)0*$")
    end
    local precision = math.max(decimals(step), decimals(self:Read("min")))
    local text = string.format("%." .. precision .. "f", value)
    if precision > 0 then
        text = text:gsub("0+$", ""):gsub("%.$", "")
    end
    return text
end

---Open the color picker on a color option; cancelling restores the previous color.
function Option:PickColor()
    local r, g, b, a = self:Read("get")
    local function changed()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        if not self:Read("disabled") then
            self:Apply(red, green, blue, ColorPickerFrame:GetColorAlpha())
        end
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r,
        g = g,
        b = b,
        opacity = a or 1,
        hasOpacity = self:Read("hasAlpha"),
        swatchFunc = changed,
        opacityFunc = changed,
        cancelFunc = function()
            self:Apply(r, g, b, a)
        end,
    })
end

function Option:Read(member, ...)
    local group, value, handler = self.root, nil, self.root.handler
    if inherited[member] then
        value = group[member]
    end
    local info = { [0] = self.appName, options = self.root, uiType = "dialog", uiName = "SeamlessConfig-1.0" }
    for index, key in ipairs(self.path) do
        group = assert(group.args[key], "Missing config option: " .. key)
        info[index] = key
        handler = group.handler or handler
        if inherited[member] and group[member] ~= nil then
            value = group[member]
        end
    end
    if not inherited[member] then
        value = group[member]
    end
    if member == "default" then
        return value
    end
    info.option, info.type, info.arg, info.handler = group, group.type, group.arg, handler
    if type(value) == "function" then
        return value(info, ...)
    end
    if type(value) == "string" and methods[member] and handler and type(handler[value]) == "function" then
        return handler[value](handler, info, ...)
    end
    return value
end

-- True when this option or one of its groups declares layout storage: its value lives
-- in the Edit Mode layout, not the profile.
function Option:InEditModeLayout()
    local group = self.root
    for _, key in ipairs(self.path) do
        group = group.args and group.args[key]
        if not group then
            return false
        end
        if group.layoutStored or group.editMode then
            return true
        end
    end
    return false
end

---Visible children in display order; with includeHidden, also those hidden now.
---@param includeHidden boolean?
function Option:Children(includeHidden)
    local group = self.root
    for _, key in ipairs(self.path) do
        group = group.args[key]
    end
    local children = {}
    for key in pairs(group.args or {}) do
        local path = {}
        for index, part in ipairs(self.path) do
            path[index] = part
        end
        path[#path + 1] = key
        local child = self:New(self.root, path, self.appName)
        if includeHidden or not child:Read("hidden") then
            child.order = child:Read("order") or 100
            children[#children + 1] = child
        end
    end
    table.sort(children, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.path[#a.path] < b.path[#b.path]
    end)
    return children
end

function Option:Choices()
    local values, result = self:Read("values") or {}, {}
    local sorting = self:Read("sorting")
    if sorting then
        for _, key in ipairs(sorting) do
            if values[key] ~= nil then
                result[#result + 1] = { value = key, text = values[key] }
            end
        end
    else
        for key, text in pairs(values) do
            result[#result + 1] = { value = key, text = text }
        end
        table.sort(result, function(a, b)
            return tostring(a.text) < tostring(b.text)
        end)
    end
    return result
end
