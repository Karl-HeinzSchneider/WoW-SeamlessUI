---@type string, SeamlessCore
local _, app = ...

-- The Position section of Edit Mode windows, as rows for the shared renderer (editmoderows.lua):
-- Anchor, AnchorParent, AnchorFrame, X, Y, "Quick anchor to frame", Revert and the reason
-- the last change was refused. A separate Size section displays the disabled Scale slider.
-- The binding reads and writes the frame; this file only builds rows.

local addon = app.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Anchor points in dropdown order and their labels, shared with editmodelib.lua.
local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POINT_LABELS = {
    TOPLEFT = L["Top left"],
    TOP = L["Top"],
    TOPRIGHT = L["Top right"],
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"],
    BOTTOMLEFT = L["Bottom left"],
    BOTTOM = L["Bottom"],
    BOTTOMRIGHT = L["Bottom right"],
}
app.EditModePoints, app.EditModePointLabels = POINTS, POINT_LABELS

-- At most two decimals: a dragged frame's offsets carry long float tails.
local function formatNumber(value)
    value = tonumber(value) or 0
    return string.format("%.12g", math.floor(value * 100 + 0.5) / 100)
end

---@class SeamlessCore.EditModePositionBinding
---@field frame table The frame being positioned (the anchor picker's source).
---@field isCurrent fun(): boolean Whether that frame is still the selected one.
---@field canEdit fun(): boolean
---@field read fun(): table? point, relativePoint, relativeTo, offsetX and offsetY.
---@field apply fun(values: table): boolean, string? Validates and applies a full set of values.
---@field readScale fun(): number, number, number, number, any? Value, min, max, step and the setting behind it (nil: greyed out).
---@field applyScale fun(value: any): boolean, string?
---@field anchorFrames fun(): table[] AnchorFrame choices, `{ text, value }`.
---@field anchorFrameText fun(value: any): string Dropdown text for a value.
---@field anchorFrame? fun(value: any): table? The frame of a choice (default: the global of that name).
---@field isValidTarget fun(target: table): boolean Whether the frame may anchor to target.
---@field hasChanges fun(): boolean Whether Revert has anything to restore.
---@field revert fun(): boolean, string?
---@field default? fun(key: string): any The default of a value key (as in read, or "scale") for the tooltips; nil shows Not applicable.

---A Position section for LayoutEditModeSections, bound to one frame. Build a new one when the
---selection changes: it keeps the last refusal message for that frame only.
---@param id string Section id, unique in its window.
---@param binding SeamlessCore.EditModePositionBinding
---@return SeamlessCore.EditModeSection
function addon:CreateEditModePositionSection(id, binding)
    local section = { id = id, name = L["Position"], key = addon:GetEditModePositionSectionKey() }
    local function commit(ok, err)
        section.error = not ok and err or nil
    end
    local function resolve(value)
        if binding.anchorFrame then
            return binding.anchorFrame(value)
        end
        return type(value) == "string" and _G[value] or nil
    end
    local function anchored()
        local values = binding.read()
        return binding.canEdit() and values ~= nil and values.point ~= nil
    end
    local function notAnchored()
        return not anchored()
    end
    local function default(key)
        return binding.default and function()
            return binding.default(key)
        end
    end
    local function get(key)
        return function()
            local values = binding.read()
            return values and values[key]
        end
    end
    local function set(key)
        return function(value)
            if not binding.isCurrent() then
                return
            end
            local values = binding.read()
            if not values or tostring(values[key]) == tostring(value) then
                return
            end
            values[key] = value
            commit(binding.apply(values))
        end
    end
    local points = {}
    for _, point in ipairs(POINTS) do
        points[#points + 1] = { text = POINT_LABELS[point], value = point }
    end
    local function pointText(value)
        return POINT_LABELS[value] or L["Unknown"]
    end
    local function offset(key, name, size)
        -- Screen-sized ranges, expanded for an existing offset so large layouts are never
        -- clamped merely by opening the window.
        local function extent()
            local value = tonumber(get(key)()) or 0
            return math.max(1, math.ceil(size()), math.ceil(math.abs(value)))
        end
        return {
            key = key,
            type = "range",
            name = name,
            editable = true,
            format = formatNumber,
            min = function()
                return -extent()
            end,
            max = extent,
            step = 1,
            default = default(key),
            get = get(key),
            set = set(key),
            disabled = notAnchored,
        }
    end
    section.options = {
        {
            key = "point",
            type = "select",
            name = L["Anchor"],
            values = points,
            text = pointText,
            default = default("point"),
            get = get("point"),
            set = set("point"),
            disabled = notAnchored,
        },
        {
            key = "relativePoint",
            type = "select",
            name = L["AnchorParent"],
            values = points,
            text = pointText,
            default = default("relativePoint"),
            get = get("relativePoint"),
            set = set("relativePoint"),
            disabled = notAnchored,
        },
        {
            key = "relativeTo",
            type = "select",
            name = L["AnchorFrame"],
            scroll = 400,
            values = function()
                local entries = {}
                for _, entry in ipairs(binding.anchorFrames()) do
                    local target = resolve(entry.value)
                    entries[#entries + 1] = {
                        text = entry.text,
                        value = entry.value,
                        disabled = not (target and binding.isValidTarget(target)),
                    }
                end
                return entries
            end,
            text = binding.anchorFrameText,
            default = default("relativeTo"),
            get = get("relativeTo"),
            set = set("relativeTo"),
            disabled = notAnchored,
        },
        offset("offsetX", L["X"], function()
            return UIParent:GetWidth()
        end),
        offset("offsetY", L["Y"], function()
            return UIParent:GetHeight()
        end),
        {
            -- Pick an anchor point on this frame, then on another frame, instead of the dropdowns.
            key = "quickAnchor",
            type = "button",
            name = L["Quick anchor to frame"],
            disabled = notAnchored,
            click = function()
                if not binding.canEdit() then
                    return
                end
                addon:StartEditModeAnchorPicker({
                    frame = binding.frame,
                    targets = function()
                        local targets = {}
                        for _, entry in ipairs(binding.anchorFrames()) do
                            local target = resolve(entry.value)
                            if target and target ~= UIParent and binding.isValidTarget(target) then
                                targets[#targets + 1] = { frame = target, value = entry.value }
                            end
                        end
                        return targets
                    end,
                    apply = function(point, relativeTo, relativePoint, x, y)
                        if not binding.isCurrent() then
                            return
                        end
                        commit(binding.apply({
                            point = point,
                            relativeTo = relativeTo,
                            relativePoint = relativePoint,
                            offsetX = x,
                            offsetY = y,
                        }))
                    end,
                })
            end,
        },
        {
            key = "error",
            type = "text",
            get = function()
                return section.error
            end,
            hidden = function()
                return section.error == nil
            end,
        },
    }
    section.revertButton = {
        key = "revert",
        type = "button",
        name = HUD_EDIT_MODE_REVERT_CHANGES or L["Revert changes"],
        disabled = function()
            return not (binding.canEdit() and binding.hasChanges())
        end,
        click = function()
            commit(binding.revert())
        end,
    }
    section.sizeSection = {
        id = id .. ":size",
        name = L["Size"],
        key = "settings:size",
        options = {
            {
                key = "scale",
                type = "range",
                name = L["Scale"],
                editable = true,
                format = formatNumber,
                default = default("scale"),
                get = function()
                    return (binding.readScale())
                end,
                min = function()
                    return select(2, binding.readScale())
                end,
                max = function()
                    return select(3, binding.readScale())
                end,
                step = function()
                    return select(4, binding.readScale())
                end,
                set = function() end,
                disabled = function()
                    return true
                end,
                -- Revert can restore an external change while the slider stays disabled.
                restore = binding.applyScale,
            },
        },
    }
    return section
end
