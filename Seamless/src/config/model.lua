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
        return false, character
    end
    if default == "1" then
        return true, character
    end
    return default, character
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

function Option:TooltipDetails()
    local resolver = app.config.optionInfo and app.config.optionInfo[self.appName]
    local value, perCharacter = self:Read("default"), nil
    if type(value) == "function" then
        value = value()
    end
    if resolver then
        local resolved
        resolved, perCharacter = resolver(self.path)
        if value == nil then
            value = resolved
        end
    end
    if value == nil then
        return L["Not applicable"], perCharacter
    end
    if type(value) == "boolean" then
        return value and L["Enabled"] or L["Disabled"], perCharacter
    end
    if self:Read("type") == "select" then
        for _, choice in ipairs(self:Choices()) do
            if choice.value == value then
                return choice.text, perCharacter
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
                perCharacter
        end
        return L["Not applicable"], perCharacter
    end
    return value == "" and L["None"] or tostring(value), perCharacter
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

-- True when this option or one of its groups is tagged `editMode`: its value lives
-- in the Edit Mode layout, not the profile.
function Option:InEditModeLayout()
    local group = self.root
    for _, key in ipairs(self.path) do
        group = group.args and group.args[key]
        if not group then
            return false
        end
        if group.editMode then
            return true
        end
    end
    return false
end

function Option:Children()
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
        if not child:Read("hidden") then
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
