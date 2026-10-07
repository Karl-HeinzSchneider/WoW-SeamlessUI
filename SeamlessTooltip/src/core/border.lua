---@type string, SeamlessTooltip
local _, app = ...

-- The border color of a top-level tooltip, set by the features that color it by its content (a
-- unit's class, an item's quality). A color holds until the tooltip is cleared or hidden, then the
-- border goes back to its base color. The border is the game's NineSlice, or the frame a feature
-- draws it with instead (Backdrop), which registers itself here with its own base color.
---@class SeamlessTooltip.Border
local border = {}
app.border = border

---@alias SeamlessTooltip.RGBA { r: number, g: number, b: number, a: number }

-- Per tooltip: the frame drawing its border instead of the NineSlice, and that frame's base color.
---@type table<GameTooltip, { frame: Frame|BackdropTemplate, color: SeamlessTooltip.RGBA }>
local frames = {}
-- Per tooltip: the NineSlice's border color before it was first painted.
---@type table<GameTooltip, SeamlessTooltip.RGBA>
local nineSliceColors = {}
-- Tooltips whose clear/hide scripts are hooked.
---@type table<GameTooltip, boolean>
local hooked = {}
-- Tooltips whose border shows a painted color.
---@type table<GameTooltip, boolean>
local painted = {}

---@param tooltip GameTooltip
---@param color SeamlessTooltip.RGBA
local function setColor(tooltip, color)
    local entry = frames[tooltip]
    if entry then
        entry.frame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    else
        tooltip.NineSlice:SetBorderColor(color.r, color.g, color.b, color.a)
    end
end

-- The border's base color: the registered frame's, else the NineSlice's own.
---@param tooltip GameTooltip
local function reset(tooltip)
    if not painted[tooltip] then
        return
    end
    painted[tooltip] = nil
    local entry = frames[tooltip]
    if entry then
        setColor(tooltip, entry.color)
    elseif nineSliceColors[tooltip] then
        setColor(tooltip, nineSliceColors[tooltip])
    end
end

-- The frame that draws `tooltip`'s border instead of its NineSlice, and its base color; nil gives
-- the border back to the NineSlice. Called again whenever the base color changes; a painted color
-- is dropped then (the border it was painted on goes back to its base first).
---@param tooltip GameTooltip
---@param frame? Frame|BackdropTemplate
---@param color? SeamlessTooltip.RGBA
function border.SetFrame(tooltip, frame, color)
    reset(tooltip)
    frames[tooltip] = frame and { frame = frame, color = color or { r = 1, g = 1, b = 1, a = 1 } } or nil
end

-- Colors the border of a top-level tooltip until it is cleared or hidden. Embedded tooltips and
-- ones without a NineSlice have no border of their own and are left alone.
---@param tooltip GameTooltip
---@param r number
---@param g number
---@param b number
---@param a? number
function border.Paint(tooltip, r, g, b, a)
    if not tooltip.NineSlice or tooltip.IsEmbedded then
        return
    end
    if not hooked[tooltip] then
        hooked[tooltip] = true
        tooltip:HookScript("OnTooltipCleared", reset)
        tooltip:HookScript("OnHide", reset)
    end
    if not painted[tooltip] and not frames[tooltip] then
        local nr, ng, nb, na = tooltip.NineSlice:GetBorderColor()
        nineSliceColors[tooltip] = { r = nr or 1, g = ng or 1, b = nb or 1, a = na or 1 }
    end
    painted[tooltip] = true
    setColor(tooltip, { r = r, g = g, b = b, a = a or 1 })
end
