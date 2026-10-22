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
    return { type = "group", inline = true, name = L["Position"], order = 10, args = args }
end

---A native frame's active layout is the only source of position values.
---@param getFrame fun(): table?
---@return table
function app.addon:GetNativePositionOptions(getFrame)
    local service = self:GetFramePositionService()
    local keys = { x = "offsetX", y = "offsetY" }
    local anchorFrames = {}
    return self:GetPositionOptions({
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
            local ok, err = service:Apply(frame, values)
            if not ok and err then
                app.logger:warn("%s", err)
            end
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
end
