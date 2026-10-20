---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

-- Hides the tooltips of units in the world while in combat (or always), unless a modifier key is
-- held; pressing it while hovering a unit brings its tooltip back.
local feature = app.features:NewFeature("HideUnits", {
    category = "units",
    name = L["Hide in combat"],
    desc = L["Hides unit tooltips in combat, so they don't cover what you are fighting. Hold the modifier key to see them anyway."],
    order = 60,
    enabled = false,
    defaults = {
        when = "COMBAT",
        modifier = "SHIFT",
        unitFrames = false,
    },
    options = {
        when = {
            type = "select",
            order = 10,
            name = L["Hide"],
            values = {
                COMBAT = L["In combat"],
                ALWAYS = L["Always"],
            },
            sorting = { "COMBAT", "ALWAYS" },
        },
        modifier = {
            type = "select",
            order = 20,
            name = L["Show while holding"],
            values = {
                NONE = L["Nothing"],
                SHIFT = L["Shift"],
                CTRL = L["Ctrl"],
                ALT = L["Alt"],
            },
            sorting = { "NONE", "SHIFT", "CTRL", "ALT" },
        },
        unitFrames = {
            type = "toggle",
            order = 30,
            width = "full",
            name = L["Unit frames too"],
            desc = L["Also hides the tooltips of the player, target, party and raid frames; off hides only units in the world."],
        },
    },
})

-- Whether a modifier setting's key is held.
local MODIFIER_DOWN = {
    SHIFT = IsShiftKeyDown,
    CTRL = IsControlKeyDown,
    ALT = IsAltKeyDown,
}

function feature:OnEnable()
    self:SecureHookScript(GameTooltip, "OnShow", "OnTooltipShow")
    self:RegisterEvent("MODIFIER_STATE_CHANGED", "OnModifierChanged")
end

---@param settings table
---@return boolean
local function hiding(settings)
    return settings.when == "ALWAYS" or InCombatLockdown()
end

---@param settings table
---@return boolean
local function modifierDown(settings)
    local isDown = MODIFIER_DOWN[settings.modifier]
    return isDown ~= nil and isDown()
end

-- A unit's tooltip shows as soon as it is filled; hiding it right away keeps it from being seen.
---@param tooltip GameTooltip
function feature:OnTooltipShow(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit or anySecret(unit) then
        return
    end
    local settings = self:Settings()
    -- A unit in the world shows its tooltip for UIParent, a unit frame for the frame. (The unit
    -- token doesn't tell: it is "target" for a hovered unit that is also the target.)
    local owner = tooltip:GetOwner()
    local inWorld = owner == UIParent or owner == WorldFrame
    if (inWorld or settings.unitFrames) and hiding(settings) and not modifierDown(settings) then
        tooltip:Hide()
    end
end

-- The modifier pressed over a unit in the world: its tooltip, the way the game shows it.
---@param key string "LSHIFT", "RCTRL", ...
---@param down number 1 when pressed
function feature:OnModifierChanged(_, key, down)
    local settings = self:Settings()
    if down ~= 1 or settings.modifier == "NONE" or not key:find(settings.modifier, 1, true) then
        return
    end
    if GameTooltip:IsShown() or not WorldFrame:IsMouseMotionFocus() then
        return
    end
    local exists = UnitExists("mouseover")
    if anySecret(exists) or not exists then
        return
    end
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetUnit("mouseover")
end
