---@type string, SeamlessCore
local _, app = ...

-- Settings pages in Edit Mode. A frame's settings are declared once, on its page in the addon's
-- src/options/ folder; Edit Mode reads that declaration through the same option model as the
-- config window (config/model.lua), so names, tooltips, defaults, validation, confirmation,
-- disabled and hidden states are shared code. Only the look differs. `editModeHidden = true` on a
-- group or control keeps it out of Edit Mode.

local addon = app.addon
local lib = app.LibEditMode

-- Page control types and the shared renderer's row types (editmoderows.lua).
local ROW_TYPES = {
    toggle = "toggle",
    select = "select",
    range = "range",
    input = "input",
    color = "color",
    execute = "button",
    description = "text",
}

local function key(path)
    return table.concat(path, ".")
end

---A row for the shared Edit Mode renderer bound to one page option: every read, write and tooltip
---goes through the option, so it behaves exactly like its config window control.
---@param option table A config Option (GetSettingsOption).
---@param rowKey? string Row key (default: the option's path).
---@return table row
function addon:GetEditModeOptionRow(option, rowKey)
    local kind = option:Read("type")
    local rowType = assert(ROW_TYPES[kind], "Edit Mode cannot show setting type " .. tostring(kind))
    local row = {
        key = rowKey or key(option.path),
        type = rowType,
        setting = option,
        name = option:Read("name"),
        hidden = function()
            return option:Read("hidden")
        end,
        disabled = function()
            return option:Read("disabled")
        end,
        default = function()
            return (option:DefaultValue())
        end,
    }
    if rowType == "button" then
        row.click = function()
            if not option:Read("disabled") then
                option:Commit()
            end
        end
    elseif rowType == "text" then
        row.get = function()
            return option:Read("name")
        end
    elseif rowType == "color" then
        row.color = function()
            return option:Read("get")
        end
        row.pick = function()
            option:PickColor()
        end
        -- A comparable value for Revert: the color as text.
        row.get = function()
            local r, g, b, a = option:Read("get")
            return string.format("%.4f %.4f %.4f %.4f", r or 0, g or 0, b or 0, a or 1)
        end
        row.set = function(value)
            local r, g, b, a = value:match("^(%S+) (%S+) (%S+) (%S+)$")
            return option:Apply(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
        end
        row.restore = row.set
    else
        row.get = function()
            return option:Read("get")
        end
        row.set = function(value)
            if rowType == "range" and type(value) == "number" then
                value = option:Snap(value)
            end
            return option:Commit(value)
        end
        row.restore = function(value)
            option:Apply(value)
        end
        if rowType == "select" then
            row.values = function()
                local values = {}
                for _, choice in ipairs(option:Choices()) do
                    values[#values + 1] = { text = choice.text, value = choice.value }
                end
                return values
            end
        elseif rowType == "range" then
            row.min = function()
                return option:Read("min")
            end
            row.max = function()
                return option:Read("max")
            end
            row.step = function()
                return option:Read("step") or 1
            end
            row.format = function(value)
                return option:FormatRange(value)
            end
        end
    end
    return row
end

---The option of a registered page, or of a group or control on it.
---@param addonName string
---@param pageKey string
---@param path? string[] Keys below the page.
---@return table option
function addon:GetPageOption(addonName, pageKey, path)
    local panel = app.options and app.options.panels[addonName]
    assert(panel, "Register the options of " .. addonName .. " before showing its pages in Edit Mode")
    local full = { pageKey }
    for _, part in ipairs(path or {}) do
        full[#full + 1] = part
    end
    return self:GetSettingsOption(panel.options, full, addonName)
end

-- The page in display order, hidden controls included (rows hide themselves at layout time):
-- `{ group = option }` opens a group, `{ close = true }` ends it, `{ row = option }`, and the
-- Position and Size groups of GetPositionOptions as `{ position = option }` / `{ size = option }`.
local function Walk(group, entries)
    for _, child in ipairs(group:Children(true)) do
        if not child:Read("editModeHidden") then
            local kind = child:Read("type")
            if child:Read("editModePosition") then
                entries[#entries + 1] = { position = child }
            elseif child:Read("editModeSize") then
                entries[#entries + 1] = { size = child }
            elseif kind == "group" then
                entries[#entries + 1] = { group = child }
                Walk(child, entries)
                entries[#entries + 1] = { close = true }
            elseif kind == "header" then
                entries[#entries + 1] = { group = child }
            else
                entries[#entries + 1] = { row = child }
            end
        end
    end
    return entries
end

-- The rows a Position or Size group adds to the generated ones.
local function GroupRows(option, leafKeys)
    local rows = {}
    for _, child in ipairs(option:Children(true)) do
        if not child:Read("editModeHidden") and ROW_TYPES[child:Read("type")] then
            rows[#rows + 1] = addon:GetEditModeOptionRow(child, leafKeys and child.path[#child.path] or nil)
        end
    end
    return rows
end

local function SectionKey(option)
    return "page:" .. option.appName .. ":" .. key(option.path)
end

---Renderer sections (LayoutEditModeSections) for a page or a group on it, for a window that
---draws its own Position section, such as the one below a Blizzard frame's settings: groups become
---collapsible sections, Position is left out, and a Size group's own rows go to a section keyed
---"settings:size" with their plain keys, which that window merges into its Size section.
---@param addonName string
---@param pageKey string
---@param spec? { path?: string[], id?: string, name?: string, key?: string }
---@return SeamlessCore.EditModeSection[]
function addon:GetEditModePageSections(addonName, pageKey, spec)
    spec = spec or {}
    local root = self:GetPageOption(addonName, pageKey, spec.path)
    local id = spec.id or ("page:" .. addonName .. ":" .. key(root.path))
    local sections = {}
    local current = { id = id, name = spec.name, key = spec.key or SectionKey(root), options = {} }
    sections[1] = current
    local count = 0
    local function open(name, sectionKey, hidden)
        count = count + 1
        current = { id = id .. ":" .. count, name = name, key = sectionKey, hidden = hidden, options = {} }
        sections[#sections + 1] = current
    end
    for _, entry in ipairs(Walk(root, {})) do
        if entry.group then
            local option = entry.group
            open(option:Read("name"), SectionKey(option), function()
                return option:Read("hidden")
            end)
        elseif entry.close then
            open()
        elseif entry.size then
            local rows = GroupRows(entry.size, true)
            if #rows > 0 then
                sections[#sections + 1] =
                    { id = id .. ":size", name = entry.size:Read("name"), key = "settings:size", options = rows }
            end
            open()
        elseif entry.row then
            current.options[#current.options + 1] = self:GetEditModeOptionRow(entry.row)
        end
    end
    local result = {}
    for _, section in ipairs(sections) do
        if #section.options > 0 then
            result[#result + 1] = section
        end
    end
    return result
end

---LibEditMode settings for a suite frame (AddFrameSettings), built from its page: a Header per
---group, the Position group as the shared Position section (with any rows the page adds to it), and
---the page's declared buttonSection footer.
---@param addonName string
---@param pageKey string
---@param path? string[] A group on the page.
---@return table[] settings
function addon:GetEditModePageSettings(addonName, pageKey, path)
    local root = self:GetPageOption(addonName, pageKey, path)
    local settings = {}
    local closed = 0
    for _, entry in ipairs(Walk(root, {})) do
        if entry.group then
            local option = entry.group
            settings[#settings + 1] = {
                kind = lib.SettingType.Header,
                name = option:Read("name"),
                key = SectionKey(option),
                hidden = function()
                    return option:Read("hidden")
                end,
            }
        elseif entry.close then
            -- Rows after a group go on without its header.
            closed = closed + 1
            settings[#settings + 1] = { kind = lib.SettingType.Header, key = SectionKey(root) .. ":" .. closed }
        elseif entry.position then
            local extras = {}
            for _, row in ipairs(GroupRows(entry.position)) do
                extras[#extras + 1] = { kind = lib.SettingType.Option, row = row }
            end
            settings[#settings + 1] = self:GetEditModePositionSetting(entry.position:Read("editModePosition"), extras)
        elseif entry.row then
            settings[#settings + 1] = { kind = lib.SettingType.Option, row = self:GetEditModeOptionRow(entry.row) }
        end
    end
    local buttons = self:GetPageOption(addonName, pageKey):Read("buttonSection")
    if buttons then
        settings[#settings + 1] = buttons
    end
    return settings
end
