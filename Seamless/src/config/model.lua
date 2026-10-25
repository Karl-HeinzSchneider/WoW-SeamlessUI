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

function Option:DefaultValue()
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
    return value, perCharacter
end

function Option:TooltipDetails()
    local value, perCharacter = self:DefaultValue()
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
    if
        member == "new"
        or member == "blizzard"
        or member == "editMode"
        or member == "hideInEditmode"
        or member == "default"
    then
        return app.config:GetOptionTags(group)[member]
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
        if app.config:GetOptionTags(group).editMode then
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

-- Bind a frame (or a resolver for a native frame) to its existing settings subtree.
-- Resolvers run at use time, including when Blizzard loads a frame late.
app.config.editModeBindings = {}
app.config.nativeFrames = setmetatable({}, { __mode = "k" })
app.config.positionGroups = setmetatable({}, { __mode = "k" })

function app.addon:RegisterEditModeSettings(frame, name, path, enabled)
    local bindings = app.config.editModeBindings
    for _, binding in ipairs(bindings) do
        if
            binding.frame == frame
            and binding.name == name
            and table.concat(binding.path, ":") == table.concat(path, ":")
        then
            binding.enabled = enabled
            return
        end
    end
    bindings[#bindings + 1] = { frame = frame, name = name, path = path, enabled = enabled }
end

-- Groups are visibility boundaries: hideInEditmode hides the whole subtree when true.
function app.addon:GetEditModeOptionSections(name, path)
    local panel = app.options.panels[name]
    if not panel then
        return {}
    end
    app.config:NormalizeOptionTags(panel.options)
    local root = app.config.Option:New(panel.options, path, name)
    local sections = {}
    local function visit(option, section)
        if
            app.config.positionGroups[option:Read("args")]
            or option:Read("hideInEditmode") == true
            or option:Read("hidden")
        then
            return
        end
        local kind = option:Read("type")
        if kind == "group" then
            local nextSection = {
                configOptions = true,
                id = name .. ":" .. table.concat(option.path, ":"),
                name = option:Read("name"),
                key = "settings:" .. name .. ":" .. table.concat(option.path, ":"),
                options = {},
            }
            for _, child in ipairs(option:Children()) do
                if child:Read("type") == "header" then
                    if child:Read("hideInEditmode") ~= true then
                        nextSection = {
                            configOptions = true,
                            id = name .. ":" .. table.concat(child.path, ":"),
                            name = child:Read("name"),
                            key = "settings:" .. name .. ":" .. table.concat(child.path, ":"),
                            options = {},
                        }
                    end
                else
                    visit(child, nextSection)
                    -- Subsequent siblings follow a nested group, rather than moving above it.
                    if child:Read("type") == "group" then
                        nextSection = {
                            configOptions = true,
                            id = name .. ":after:" .. table.concat(child.path, ":"),
                            options = {},
                        }
                    end
                end
            end
        elseif kind == "header" then
            -- Header sections are handled with their following siblings below.
        else
            if #section.options == 0 then
                sections[#sections + 1] = section
            end
            section.options[#section.options + 1] = {
                key = table.concat(option.path, ":") .. ":" .. kind,
                type = "config",
                option = option,
                hidden = function()
                    return option:Read("hidden") or option:Read("hideInEditmode") == true
                end,
                disabled = function()
                    return InCombatLockdown() or option:Read("disabled")
                end,
            }
        end
    end
    -- Check ancestor visibility as well as the selected group.
    local group = panel.options
    for _, key in ipairs(path) do
        if app.config:GetOptionTags(group).hideInEditmode == true or not group.args or not group.args[key] then
            return {}
        end
        group = group.args[key]
    end
    visit(root, { id = name .. ":" .. table.concat(path, ":"), options = {} })
    local result = {}
    for _, section in ipairs(sections) do
        if #section.options > 0 then
            result[#result + 1] = section
        end
    end
    return result
end

function app.addon:GetEditModeSettingsSections(frame)
    local sections, owners, seen = {}, {}, {}
    for _, binding in ipairs(app.config.editModeBindings) do
        local target = binding.frame
        if type(target) == "function" then
            target = target()
        end
        local key = binding.name .. ":" .. table.concat(binding.path, ":")
        if target == frame and not seen[key] and (not binding.enabled or binding.enabled()) then
            seen[key] = true
            owners[binding.name] = true
            for _, section in ipairs(self:GetEditModeOptionSections(binding.name, binding.path)) do
                section.order = #sections + 1
                sections[#sections + 1] = section
            end
        end
    end
    return sections, owners
end

-- Position keeps its specialized controls, but observes the same declaration visibility flags.
function app.addon:FilterEditModePositionSection(frame, section)
    for _, binding in ipairs(app.config.editModeBindings) do
        local target = binding.frame
        if type(target) == "function" then
            target = target()
        end
        local panel = app.options.panels[binding.name]
        if target == frame and panel and (not binding.enabled or binding.enabled()) then
            local function find(option, excluded)
                excluded = excluded or option:Read("hideInEditmode") == true or option:Read("hidden")
                local args = option:Read("args")
                if app.config.positionGroups[args] then
                    local result = {}
                    for key, value in pairs(section) do
                        result[key] = value
                    end
                    result.hidden = excluded or section.hidden
                    result.options = {}
                    for _, row in ipairs(section.options) do
                        local copy = {}
                        for key, value in pairs(row) do
                            copy[key] = value
                        end
                        local child = args[row.key]
                        local wasHidden = row.hidden
                        copy.hidden = function()
                            return excluded
                                or (child and app.config:GetOptionTags(child).hideInEditmode == true)
                                or (type(wasHidden) == "function" and wasHidden())
                                or wasHidden == true
                        end
                        result.options[#result.options + 1] = copy
                    end
                    return result
                end
                for key, child in pairs(args or {}) do
                    if child.type == "group" then
                        local path = {}
                        for index, part in ipairs(option.path) do
                            path[index] = part
                        end
                        path[#path + 1] = key
                        local found = find(app.config.Option:New(panel.options, path, binding.name), excluded)
                        if found then
                            return found
                        end
                    end
                end
            end
            local option = app.config.Option:New(panel.options, binding.path, binding.name)
            local filtered = find(option)
            if filtered then
                return filtered
            end
        end
    end
    return section
end
