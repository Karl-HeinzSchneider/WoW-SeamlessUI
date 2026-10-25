---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Sizes the tooltips on their own, apart from the UI scale.
local feature = app.features:NewFeature("Scale")

-- The top-level tooltips, and the comparison tooltips beside them (not their children, so they
-- need a scale of their own).
local TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
}

-- Each tooltip's scale before ours, put back when the feature is switched off.
---@type table<Frame, number>
local originalScales = {}

function feature:OnEnable()
    self:ApplySettings()
end

function feature:OnDisable()
    for tooltip, scale in pairs(originalScales) do
        tooltip:SetScale(scale)
    end
    originalScales = {}
end

function feature:ApplySettings()
    local scale = self:Settings().scale
    for _, name in ipairs(TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip then
            originalScales[tooltip] = originalScales[tooltip] or tooltip:GetScale()
            tooltip:SetScale(originalScales[tooltip] * scale)
        end
    end
end
