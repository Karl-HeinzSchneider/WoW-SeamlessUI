---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local config = { categories = {}, collapsed = {}, pages = {}, rows = {} }
app.config = config

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
    config.categories[id] = {
        id = id,
        name = spec.name,
        parent = spec.parent,
        order = spec.order or 100,
        header = spec.header,
        create = spec.create,
        refresh = spec.refresh,
    }
    if config.frame then
        config:Refresh()
    end
end

function config:GetChildren(parent)
    local children = {}
    for _, category in pairs(self.categories) do
        if category.parent == parent then
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

-- A small real tree for reviewing the shell; addon options are migrated separately.
app.addon:RegisterConfigCategory("Seamless", { name = L["Seamless"], header = true, order = 0 })
app.addon:RegisterConfigCategory("Seamless:general", { name = L["General"], parent = "Seamless", order = 0 })
config.selected = "Seamless:general"
