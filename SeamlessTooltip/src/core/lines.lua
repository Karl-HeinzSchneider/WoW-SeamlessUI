---@type string, SeamlessTooltip
local _, app = ...

-- The lines features add to tooltips, in one look: the label on the left in the game's gold, the
-- value on the right in white or a color of its own.
---@class SeamlessTooltip.Lines
local lines = {}
app.lines = lines

---@param tooltip GameTooltip
---@param label string
---@param value any shown with tostring
---@param color? ColorMixin the value's color (default white)
function lines.AddValue(tooltip, label, value, color)
    local labelR, labelG, labelB = NORMAL_FONT_COLOR:GetRGB()
    local valueR, valueG, valueB = (color or HIGHLIGHT_FONT_COLOR):GetRGB()
    tooltip:AddDoubleLine(label, tostring(value), labelR, labelG, labelB, valueR, valueG, valueB)
end
