---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Anchors every tooltip that would go to the default spot in the screen corner (units in the
-- world, most frames) to the mouse cursor instead. Unit frames keep the default spot.
local feature = app.features:NewFeature("CursorAnchor")

-- Post-hook (AceHook drops it when the feature is switched off). Every caller of the default anchor
-- fills the tooltip afterwards, so re-owning it here loses nothing.
function feature:OnEnable()
    self:SecureHook("GameTooltip_SetDefaultAnchor", "AnchorToCursor")
end

-- Blizzard's unit frames (player, target, party, raid, ...) carry their unit in `.unit`, secure unit
-- buttons (unit frame addons) in the "unit" attribute. Units in the world come with UIParent.
---@param frame Frame
---@return boolean
local function isUnitFrame(frame)
    return frame ~= UIParent and (frame.unit ~= nil or frame:GetAttribute("unit") ~= nil)
end

---@param tooltip GameTooltip
---@param parent Frame
function feature:AnchorToCursor(tooltip, parent)
    -- A forbidden parent can't be touched from addon code; unit frames keep the default anchor.
    if not parent or parent:IsForbidden() or isUnitFrame(parent) then
        return
    end
    local settings = self:Settings()
    -- The default anchor pins the tooltip to the screen corner with a point of its own.
    tooltip:ClearAllPoints()
    tooltip:SetOwner(parent, settings.position, settings.offsetX, settings.offsetY)
end
