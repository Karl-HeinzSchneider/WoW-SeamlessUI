---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Anchors the tooltip of an action button (action, pet and stance bars) to that button instead of
-- the default spot in the screen corner.
local feature = app.features:NewFeature("ActionButtonAnchor", {
    category = "all",
    name = L["Anchor to action buttons"],
    desc = L["Shows the tooltip of an action bar, pet bar or stance bar button next to that button."],
    order = 20,
    options = {
        position = {
            type = "select",
            order = 10,
            name = L["Position"],
            values = {
                AUTO = L["Above or below (toward the screen center)"],
                ANCHOR_TOP = L["Above"],
                ANCHOR_BOTTOM = L["Below"],
                ANCHOR_LEFT = L["Above, to the left"],
                ANCHOR_RIGHT = L["Above, to the right"],
            },
            sorting = { "AUTO", "ANCHOR_TOP", "ANCHOR_BOTTOM", "ANCHOR_LEFT", "ANCHOR_RIGHT" },
        },
    },
})

-- The GameTooltip methods action buttons fill their tooltip with. Every bar calls one of them after
-- choosing the owner, Blizzard's own buttons and those of bar addons alike.
local SETTERS = { "SetAction", "SetPetAction", "SetShapeshift" }

-- Post-hooks (AceHook drops them when the feature is switched off).
function feature:OnEnable()
    for _, setter in ipairs(SETTERS) do
        self:SecureHook(GameTooltip, setter, "AnchorToOwner")
    end
end

---@param owner Frame
---@return TooltipAnchor
local function autoAnchor(owner)
    local _, y = owner:GetCenter()
    if not y then
        return "ANCHOR_TOP"
    end
    local screenMiddle = UIParent:GetHeight() * UIParent:GetEffectiveScale() / 2
    return y * owner:GetEffectiveScale() < screenMiddle and "ANCHOR_TOP" or "ANCHOR_BOTTOM"
end

-- Runs after the setter filled the tooltip; the owner is the button that asked for it.
---@param tooltip GameTooltip
function feature:AnchorToOwner(tooltip)
    local owner = tooltip:GetOwner()
    if not owner or owner == UIParent or not tooltip:IsShown() then
        return
    end
    local position = self:Settings().position
    -- The default anchor pins the tooltip to the screen corner with a point of its own.
    tooltip:ClearAllPoints()
    tooltip:SetAnchorType(position == "AUTO" and autoAnchor(owner) or position)
    -- Lay the tooltip out again at the new anchor.
    tooltip:Show()
end
