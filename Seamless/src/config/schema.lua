---@type string, SeamlessCore
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessCore.SettingsOption : AceConfig.OptionsTable
---@field new? boolean
---@field blizzard? boolean
---@field editMode? boolean
---@field default? any|fun(): any
---@field feature? boolean Supply the shared feature switch and settings bindings.
---@field settings? fun(): table Resolve the current profile's feature settings.
---@field toggled? fun() Reapply a feature after its enabled state changes.
---@field changed? fun() Reapply subordinate settings.
---@field args? table<string, SeamlessCore.SettingsOption>

---@class SeamlessCore.SettingsPage
---@field defaults AceDB.Schema Saved defaults at their existing database paths.
---@field config SeamlessCore.SettingsOption A group displayed as one navigation page.
---@field tooltip? fun(path: string[]): any, boolean?

local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            assert(type(target[key]) == "table", "Conflicting settings defaults: " .. key)
            merge(target[key], value)
        else
            assert(target[key] == nil or target[key] == value, "Conflicting settings defaults: " .. key)
            target[key] = value
        end
    end
end

-- Called before AceDB initialization. Pages own defaults; database files own only schema/data.
function app.addon:GetOptionsDefaults(pages, defaults)
    defaults = defaults or {}
    for _, page in pairs(pages) do
        assert(type(page.defaults) == "table" and type(page.config) == "table", "Invalid settings page")
        merge(defaults, page.defaults)
    end
    return defaults
end

local function featureGroup(spec)
    -- A feature with no subordinate settings needs only a clearly named switch.
    if not spec.args or not next(spec.args) then
        return {
            type = "toggle",
            new = spec.new,
            blizzard = spec.blizzard,
            editMode = spec.editMode,
            order = spec.order,
            width = "full",
            name = spec.name,
            desc = spec.desc,
            descStyle = "inline",
            get = function()
                return spec.settings().enabled
            end,
            set = function(_, value)
                spec.settings().enabled = value
                if spec.toggled then
                    spec.toggled()
                end
            end,
            disabled = function()
                return false
            end,
        }
    end
    local args = {
        enabled = {
            type = "toggle",
            order = 0,
            width = "full",
            name = L["Enable"],
            desc = spec.desc,
            descStyle = "inline",
        },
    }
    for key, option in pairs(spec.args or {}) do
        assert(key ~= "enabled", "Feature options must not redefine enabled")
        args[key] = option
    end
    return {
        type = "group",
        new = spec.new,
        blizzard = spec.blizzard,
        editMode = spec.editMode,
        inline = true,
        order = spec.order,
        name = spec.name,
        args = args,
        get = function(info)
            local value = spec.settings()[info[#info]]
            if info.type == "color" then
                return value.r, value.g, value.b, value.a
            end
            return value
        end,
        set = function(info, value, g, b, a)
            local key, settings = info[#info], spec.settings()
            if info.type == "color" then
                local color = settings[key]
                color.r, color.g, color.b = value, g, b
                if info.option.hasAlpha then
                    color.a = a
                end
            else
                settings[key] = value
            end
            if key == "enabled" then
                if spec.toggled then
                    spec.toggled()
                end
            elseif spec.changed then
                spec.changed()
            end
        end,
        disabled = function(info)
            return info[#info] ~= "enabled" and not spec.settings().enabled
        end,
    }
end

local prepared = setmetatable({}, { __mode = "k" })
local kinds = {
    group = true,
    header = true,
    toggle = true,
    select = true,
    range = true,
    input = true,
    color = true,
    execute = true,
    description = true,
}
function app.addon:PrepareSettingsOptions(option)
    assert(
        type(option) == "table" and kinds[option.type],
        "Unsupported Seamless setting type: " .. tostring(option.type)
    )
    for _, key in ipairs({ "new", "blizzard", "editMode", "feature" }) do
        assert(option[key] == nil or type(option[key]) == "boolean", "Setting " .. key .. " must be a boolean")
    end
    if option.feature and not prepared[option] then
        assert(
            type(option.name) == "string" and type(option.settings) == "function",
            "Feature settings require a name and settings accessor"
        )
        prepared[option] = true
        local generated = featureGroup(option)
        for key, value in pairs(generated) do
            if option[key] == nil or key == "type" or key == "args" then
                option[key] = value
            end
        end
    end
    for _, child in pairs(option.args or {}) do
        self:PrepareSettingsOptions(child)
    end
end
