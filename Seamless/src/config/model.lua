---@type string, SeamlessCore
local _, app = ...

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

function Option:Read(member, ...)
    local group, value, handler = self.root, nil, self.root.handler
    if inherited[member] then
        value = group[member]
    end
    local info = { [0] = self.appName, options = self.root, uiType = "dialog", uiName = "SeamlessConfig" }
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
    info.option, info.type, info.arg, info.handler = group, group.type, group.arg, handler
    if type(value) == "function" then
        return value(info, ...)
    end
    if type(value) == "string" and methods[member] and handler and type(handler[value]) == "function" then
        return handler[value](handler, info, ...)
    end
    return value
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
