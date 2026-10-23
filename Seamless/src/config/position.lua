---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---Build a reusable Position section from the same get/set contract as Edit Mode.
---@param spec SeamlessCore.EditModePosition
---@return table
function app.addon:GetPositionOptions(spec)
    local args = {}
    local function disabled()
        return InCombatLockdown() or (spec.disabled and spec.disabled()) or false
    end
    local function option(key, name, order, kind)
        local row = {
            type = kind,
            name = name,
            order = order,
            disabled = disabled,
            get = function()
                return spec.get(key)
            end,
            set = function(_, value)
                if not disabled() then
                    spec.set(key, value)
                end
            end,
            default = spec.default and function()
                return spec.default(key)
            end,
        }
        args[key] = row
        return row
    end
    local points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local labels = {
        L["Top left"],
        L["Top"],
        L["Top right"],
        L["Left"],
        L["Center"],
        L["Right"],
        L["Bottom left"],
        L["Bottom"],
        L["Bottom right"],
    }
    local values = {}
    for i, point in ipairs(points) do
        values[point] = labels[i]
    end
    for i, key in ipairs({ "point", "relativePoint" }) do
        local row = option(key, i == 1 and L["Anchor"] or L["AnchorParent"], i, "select")
        row.values, row.sorting = values, points
    end
    local frame = option("relativeTo", L["AnchorFrame"], 3, "select")
    local function choices()
        return type(spec.anchorFrames) == "function" and spec.anchorFrames() or spec.anchorFrames or {}
    end
    frame.values = function()
        local result = {}
        for _, entry in ipairs(choices()) do
            result[entry.value] = entry.text
        end
        return result
    end
    frame.sorting = function()
        local result = {}
        for _, entry in ipairs(choices()) do
            result[#result + 1] = entry.value
        end
        return result
    end
    for i, key in ipairs({ "x", "y" }) do
        local row = option(key, i == 1 and L["X"] or L["Y"], i + 3, "range")
        local extent = math.ceil(i == 1 and UIParent:GetWidth() or UIParent:GetHeight())
        local current = math.ceil(math.abs(spec.get(key) or 0))
        row.min, row.max, row.step = -math.max(extent, current), math.max(extent, current), 1
    end
    local scale = spec.scale or {}
    local scaleRow = {
        type = "range",
        name = L["Scale"],
        -- Scale leads the group, before the anchor rows.
        order = 0,
        min = scale.min or 0.5,
        max = scale.max or 2,
        step = scale.step or 0.01,
        get = scale.get or function()
            return 1
        end,
        default = scale.default,
        disabled = function()
            return not scale.get or not scale.set or disabled() or (scale.disabled and scale.disabled()) or false
        end,
    }
    scaleRow.set = function(_, value)
        if not scaleRow.disabled() and type(value) == "number" and value >= scaleRow.min and value <= scaleRow.max then
            scale.set(value)
        end
    end
    args.scale = scaleRow
    if spec.reset then
        args.reset = {
            type = "execute",
            name = L["Reset to default position"],
            order = 7,
            disabled = function()
                return disabled() or (spec.isDefault and spec.isDefault()) or false
            end,
            func = function()
                if not args.reset.disabled() then
                    spec.reset()
                end
            end,
        }
    end
    return { type = "group", inline = true, name = L["Position and scale"], order = 10, args = args }
end

---A native frame's active layout is the only source of position values, so the group
---carries the EDIT MODE tag.
---@param getFrame fun(): table?
---@param scale? SeamlessCore.PositionScale Explicit scale binding; omitted means read-only.
---@return table
function app.addon:GetNativePositionOptions(getFrame, scale)
    local service = self:GetFramePositionService()
    local keys = { x = "offsetX", y = "offsetY" }
    local anchorFrames = {}
    local scaleOptions = {
        get = function()
            local frame = getFrame()
            return frame and frame:GetScale() or 1
        end,
    }
    for key, value in pairs(scale or {}) do
        scaleOptions[key] = value
    end
    local function warn(ok, err)
        if not ok and err then
            app.logger:warn("%s", err)
        end
    end
    local group = self:GetPositionOptions({
        scale = scaleOptions,
        default = function(key)
            local values = service:GetDefault(getFrame())
            return values and values[keys[key] or key]
        end,
        isDefault = function()
            return service:IsDefault(getFrame())
        end,
        reset = function()
            warn(service:ResetToDefault(getFrame()))
        end,
        disabled = function()
            return not service:CanEdit(getFrame())
        end,
        get = function(key)
            local values = service:Read(getFrame())
            return values and values[keys[key] or key] or (keys[key] and 0 or nil)
        end,
        set = function(key, value)
            local frame = getFrame()
            local values = service:Read(frame)
            if not values then
                return
            end
            values[keys[key] or key] = value
            warn(service:Apply(frame, values))
        end,
        anchorFrames = function()
            -- Disabled dropdowns still generate their menus; do not inspect protected
            -- anchor chains during combat just to populate those menu labels.
            if not InCombatLockdown() then
                anchorFrames = service:GetAnchorFrames(getFrame())
            end
            return anchorFrames
        end,
    })
    group.editMode = true
    return group
end

---Scale bound to a native Edit Mode percentage setting, such as the unit frames'
---Frame Size: the same value, range, default and saving as the native slider.
---@param getFrame fun(): table?
---@param setting number The system's setting enum value.
---@return SeamlessCore.PositionScale
function app.addon:GetNativeSettingScale(getFrame, setting)
    local service = self:GetFramePositionService()
    local min, max, step = service:GetSettingRange(getFrame(), setting)
    return {
        min = min and min / 100,
        max = max and max / 100,
        step = step and step / 100,
        get = function()
            local value = service:ReadSetting(getFrame(), setting)
            return value and value / 100 or 1
        end,
        set = function(value)
            local ok, err = service:ApplySetting(getFrame(), setting, math.floor(value * 100 + 0.5))
            if not ok and err then
                app.logger:warn("%s", err)
            end
        end,
        disabled = function()
            return service:ReadSetting(getFrame(), setting) == nil
        end,
        default = function()
            local value = service:GetDefaultSetting(getFrame(), setting)
            return value and value / 100
        end,
    }
end
