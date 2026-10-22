---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local config = { categories = {}, collapsed = {}, pages = {}, rows = {}, optionInfo = {} }
config.optionTags = setmetatable({}, { __mode = "k" })
app.config = config

function config:GetOptionTags(option)
    local saved = self.optionTags[option] or {}
    local new, blizzard = option.new, option.blizzard
    if new == nil then
        new = saved.new
    end
    if blizzard == nil then
        blizzard = saved.blizzard
    end
    local default = option.default
    if default == nil then
        default = saved.default
    end
    return { new = new, blizzard = blizzard, default = default }
end

-- These convenience flags are ours, not AceConfig schema fields. `default` is the
-- value (or a function returning it) the custom window's tooltip shows; it wins
-- over the addon's `tooltip` resolver, for values only the game knows.
function config:NormalizeOptionTags(option)
    if option.new ~= nil or option.blizzard ~= nil or option.default ~= nil then
        assert(option.new == nil or type(option.new) == "boolean", "Option new must be a boolean")
        assert(option.blizzard == nil or type(option.blizzard) == "boolean", "Option blizzard must be a boolean")
        self.optionTags[option] = self:GetOptionTags(option)
        option.new, option.blizzard, option.default = nil, nil, nil
    end
    for _, child in pairs(option.args or {}) do
        self:NormalizeOptionTags(child)
    end
end

-- IDs belong to the registering addon (prefer an AddonName:category prefix).
-- Parents must already exist, so a registration can never introduce a cycle.
function app.addon:RegisterConfigCategory(id, spec)
    assert(type(id) == "string" and id ~= "", "Config category requires an ID")
    assert(not config.categories[id], "Duplicate config category: " .. id)
    assert(type(spec) == "table" and type(spec.name) == "string", "Config category requires a name")
    assert(not spec.parent or config.categories[spec.parent], "Unknown config parent")
    assert(spec.order == nil or type(spec.order) == "number", "Config order must be a number")
    assert(not spec.create or type(spec.create) == "function", "Config create must be a function")
    assert(not spec.refresh or type(spec.refresh) == "function", "Config refresh must be a function")
    assert(spec.new == nil or type(spec.new) == "boolean", "Config new must be a boolean")
    assert(spec.blizzard == nil or type(spec.blizzard) == "boolean", "Config blizzard must be a boolean")
    config.categories[id] = {
        id = id,
        name = spec.name,
        parent = spec.parent,
        order = spec.order or 100,
        header = spec.header,
        create = spec.create,
        refresh = spec.refresh,
        hidden = spec.hidden,
        new = spec.new,
        blizzard = spec.blizzard,
    }
    if config.frame then
        config:Refresh()
    end
end

function config:GetChildren(parent)
    local children = {}
    for _, category in pairs(self.categories) do
        local hidden = category.hidden
        if type(hidden) == "function" then
            hidden = hidden()
        end
        if category.parent == parent and not hidden then
            children[#children + 1] = category
        end
    end
    table.sort(children, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.id < b.id
    end)
    return children
end

function config:GetVisibleCategories()
    local result = {}
    local function visit(parent, depth)
        for _, category in ipairs(self:GetChildren(parent)) do
            result[#result + 1] = { category = category, depth = depth }
            if not self.collapsed[category.id] then
                visit(category.id, depth + 1)
            end
        end
    end
    visit(nil, 0)
    return result
end

function app.addon:OpenConfig(id)
    assert(not id or config.categories[id], "Unknown config category")
    if id then
        local parent = config.categories[id].parent
        while parent do
            config.collapsed[parent] = nil
            parent = config.categories[parent].parent
        end
        config.selected = id
    end
    config:CreateWindow()
    config:Refresh()
    config.frame:Show()
    config.frame:Raise()
end

function app.addon:RefreshConfig()
    if config.frame then
        config:Refresh()
    end
end

function app.addon:ToggleConfig()
    if config.frame and config.frame:IsShown() then
        config.frame:Hide()
    else
        self:OpenConfig()
    end
end

-- A small real tree for reviewing the shell; addon options are migrated separately.
app.addon:RegisterConfigCategory("Seamless", { name = L["Seamless"], header = true, order = 0 })
app.addon:RegisterConfigCategory("Seamless:general", { name = L["General"], parent = "Seamless", order = 0 })
config.selected = "Seamless:general"
