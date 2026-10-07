---@type string, SeamlessTooltip
local _, app = ...

-- Sizes the tooltips on their own, apart from the UI scale.
local feature = app.features:NewFeature("Scale", {
    category = "all",
    name = "Scale",
    desc = "Makes the tooltips bigger or smaller, apart from the rest of the interface.",
    order = 40,
    enabled = false,
    defaults = {
        scale = 1,
    },
    options = {
        scale = {
            type = "range",
            order = 10,
            name = "Scale",
            min = 0.5,
            max = 2,
            step = 0.05,
            isPercent = true,
        },
    },
})

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
