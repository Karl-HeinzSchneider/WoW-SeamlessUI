---@type string, SeamlessTooltip
local _, app = ...

local feature = app.features:NewFeature("HideHealthBar")
local healthBar = app.features:GetModule("HealthBar")
local originalAlpha

function feature:OnEnable()
    local bar = GameTooltip.StatusBar
    if bar then
        -- Blizzard can keep updating and showing its secure bar while it is transparent.
        originalAlpha = bar:GetAlpha()
        bar:SetAlpha(0)
        healthBar:SettingsChanged()
    end
end

function feature:OnDisable()
    if originalAlpha ~= nil then
        GameTooltip.StatusBar:SetAlpha(originalAlpha)
        originalAlpha = nil
        healthBar:SettingsChanged()
    end
end
