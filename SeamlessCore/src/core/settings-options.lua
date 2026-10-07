---@type string, SeamlessCore
local _, app = ...

local Panel = app.settings.Panel

---@class SeamlessCore.OptionGroup
---@field id string
---@field name string
---@field options table<string, table> # toggle/select/range/color definitions, ordered by order then key.
---@field defaults table
---@field get fun(): table # Return the current profile's settings, never a cached table.
---@field changed function
---@field enabled? fun(): boolean
---@field dependencies? string[]
---@field tags? string[]

-- A small adapter for declarative feature options. No AceConfig registration or runtime dependency.
-- Maps retain numeric keys (e.g. item quality 0); providers are evaluated each time a menu opens.
local function Choices(option)
    return function()
        local values = type(option.values) == "function" and option.values() or option.values
        local keys = option.sorting
        if not keys then
            keys = {}
            for key in pairs(values) do
                keys[#keys + 1] = key
            end
            table.sort(keys, function(a, b)
                return tostring(values[a]) < tostring(values[b])
            end)
        end
        local result = {}
        for _, key in ipairs(keys) do
            result[#result + 1] = { key, values[key] }
        end
        return result
    end
end

local function Hex(color)
    return CreateColor(color.r, color.g, color.b, 1):GenerateHexColor()
end

---@param group SeamlessCore.OptionGroup
function Panel:Options(group)
    local keys, dependencies = {}, {}
    for _, id in ipairs(group.dependencies or {}) do
        dependencies[#dependencies + 1] = id
    end
    for key in pairs(group.options) do
        keys[#keys + 1] = key
        dependencies[#dependencies + 1] = group.id .. "." .. key
    end
    table.sort(keys, function(a, b)
        local first, second = group.options[a].order or 10, group.options[b].order or 10
        return first == second and a < b or first < second
    end)
    for _, key in ipairs(keys) do
        local option = group.options[key]
        local spec = {
            id = group.id .. "." .. key,
            name = group.name .. ": " .. (type(option.name) == "string" and option.name or key),
            tooltip = option.desc,
            default = option.default,
            context = group.get,
            get = function()
                if option.get then
                    return option.get({ key, option = option })
                end
                return group.get()[key]
            end,
            set = function(value)
                if option.set then
                    option.set({ key, option = option }, value)
                else
                    group.get()[key] = value
                    group.changed()
                end
            end,
            enabled = function()
                local disabled = type(option.disabled) == "function" and option.disabled() or option.disabled == true
                local hidden = type(option.hidden) == "function" and option.hidden() or option.hidden == true
                return (not group.enabled or group.enabled()) and not disabled and not hidden
            end,
            dependencies = dependencies,
            tags = group.tags,
        }
        if spec.default == nil then
            spec.default = group.defaults[key]
        end
        if option.type == "header" then
            self:Header(spec.name)
        elseif option.type == "description" then
            self:Description(spec.name, option.name)
        elseif option.type == "execute" then
            self:Action(spec, option.func, option.confirm and (option.confirmText or (spec.name .. "?")))
        elseif option.type == "input" then
            spec.validate = option.validate
                and function(value)
                    return option.validate({ key, option = option }, value)
                end
            self:Input(spec)
        elseif option.type == "toggle" then
            self:Checkbox(spec)
        elseif option.type == "select" then
            spec.variableType = type(spec.default)
            spec.options = Choices(option)
            self:Dropdown(spec)
        elseif option.type == "range" then
            -- Use hard bounds so existing offsets outside former AceConfig soft bounds stay editable.
            spec.min, spec.max, spec.step = option.min, option.max, option.step
            if option.isPercent then
                spec.format = function(value)
                    return ("%.0f%%"):format(value * 100)
                end
            end
            self:Slider(spec)
        elseif option.type == "color" then
            spec.default = Hex(group.defaults[key])
            local function colorValue()
                if option.get then
                    local r, g, b, a = option.get({ key, option = option })
                    return { r = r, g = g, b = b, a = a }
                end
                return group.get()[key]
            end
            local function saveColor(color)
                if option.set then
                    option.set({ key, option = option }, color.r, color.g, color.b, color.a)
                else
                    group.get()[key] = color
                    group.changed()
                end
            end
            spec.get = function()
                return Hex(colorValue())
            end
            spec.set = function(value)
                local color = colorValue()
                color.r, color.g, color.b = CreateColorFromHexString(value):GetRGB()
                saveColor(color)
            end
            self:Color(spec)
            if option.hasAlpha then
                self:Slider({
                    id = spec.id .. ".opacity",
                    name = spec.name .. " opacity",
                    tooltip = option.desc,
                    default = group.defaults[key].a,
                    min = 0,
                    max = 1,
                    step = 0.01,
                    format = function(value)
                        return ("%.0f%%"):format(value * 100)
                    end,
                    get = function()
                        return colorValue().a
                    end,
                    set = function(value)
                        local color = colorValue()
                        color.a = value
                        saveColor(color)
                    end,
                    enabled = spec.enabled,
                    dependencies = dependencies,
                    tags = spec.tags,
                })
            end
        else
            error("Unsupported native option type: " .. tostring(option.type))
        end
    end
end
