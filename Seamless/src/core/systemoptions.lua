---@type string, SeamlessCore
local _, app = ...

-- Settings feature addons add to a Blizzard Edit Mode system. They are shown as collapsible
-- sections in SeamlessUI's extended window below the selected frame's native settings; Core
-- only keeps the registry, so a feature addon never depends on SeamlessUI.

local addon = app.addon
local registrations = {}

-- Sent after a registration or a feature's state change, so the window redraws.
local CHANGED = "SEAMLESS_EDITMODE_SYSTEM_OPTIONS_CHANGED"

local rowTypes = { toggle = true, select = true, range = true }

local function IsEnabled(spec)
    if type(spec.enabled) == "function" then
        return not not spec.enabled()
    end
    return spec.enabled == nil or not not spec.enabled
end

---Add a section of settings to a Blizzard Edit Mode system. Register once; call
---RefreshEditModeSystemOptions when the feature's state changes elsewhere.
---@param id string Unique section identifier.
---@param spec SeamlessCore.EditModeSystemOptions
function addon:RegisterEditModeSystemOptions(id, spec)
    assert(type(id) == "string" and id ~= "" and not registrations[id], "Edit Mode system option id must be unique")
    assert(type(spec) == "table" and spec.system ~= nil and type(spec.name) == "string", "System and name are required")
    assert(type(spec.options) == "table", "Edit Mode system options are required")
    local keys = {}
    for _, option in ipairs(spec.options) do
        assert(type(option.key) == "string" and not keys[option.key], "Edit Mode row keys must be unique")
        keys[option.key] = true
        assert(rowTypes[option.type], "Unknown Edit Mode system row type")
        assert(type(option.name) == "string", "Row label is required")
        assert(type(option.get) == "function" and type(option.set) == "function", "Row needs get/set")
        if option.type == "select" then
            assert(type(option.values) == "table", "Select needs values")
        elseif option.type == "range" then
            assert(option.min and option.max and option.step, "Range needs min, max and step")
        end
    end
    spec.id = id
    registrations[id] = spec
    self:RefreshEditModeSystemOptions()
end

---Sections for a selected Edit Mode system frame, in order. Disabled features are left out.
---@param system table The system frame the native settings dialog is attached to.
---@return SeamlessCore.EditModeSystemOptions[]
function addon:GetEditModeSystemOptions(system)
    local sections = {}
    for _, spec in pairs(registrations) do
        if
            IsEnabled(spec)
            and system.system == spec.system
            and (spec.systemIndex == nil or system.systemIndex == spec.systemIndex)
        then
            sections[#sections + 1] = spec
        end
    end
    table.sort(sections, function(a, b)
        local left, right = a.order or 100, b.order or 100
        if left ~= right then
            return left < right
        end
        return a.id < b.id
    end)
    return sections
end

---Ask the window showing system options to redraw.
function addon:RefreshEditModeSystemOptions()
    self:SendMessage(CHANGED)
end

---The message RefreshEditModeSystemOptions sends.
---@return string
function addon:GetEditModeSystemOptionsMessage()
    return CHANGED
end
