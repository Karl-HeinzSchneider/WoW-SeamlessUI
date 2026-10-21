---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

local media = app.media
local LSM = media.LSM

-- Restyles the health bar of unit (and object) tooltips: its texture and height, a background,
-- a status text like on unit frames, and optionally moves it inside the tooltip's border.
local feature -- declared first: the options below refer to it
feature = app.features:NewFeature("HealthBar", {
    category = "units",
    name = L["Health bar"],
    desc = L["Restyles the health bar of unit tooltips and can show it inside the tooltip, with a health text like on unit frames."],
    order = 30,
    options = {
        inside = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Inside the tooltip"],
            desc = L["Shows the bar at the bottom of the tooltip, inside its border, instead of below it."],
        },
        inset = {
            type = "range",
            order = 20,
            name = L["Distance from the edge"],
            desc = L["How far the bar stays inside the tooltip's edge; about the border's width."],
            min = 0,
            max = 20,
            step = 1,
            disabled = function()
                local settings = feature:Settings()
                return not settings.enabled or not settings.inside
            end,
        },
        height = {
            type = "range",
            order = 30,
            name = L["Height"],
            min = 2,
            max = 30,
            step = 1,
        },
        texture = {
            type = "select",
            order = 40,
            name = L["Texture"],
            values = media.Values(LSM.MediaType.STATUSBAR),
        },
        backgroundColor = {
            type = "color",
            order = 50,
            name = L["Background color"],
            desc = L["Behind the bar, where health is missing."],
            hasAlpha = true,
        },
        text = {
            type = "select",
            order = 60,
            name = L["Health text"],
            values = {
                NONE = L["None"],
                PERCENT = L["Percent"],
                VALUE = L["Value"],
                VALUE_MAX = L["Value / max"],
                VALUE_PERCENT = L["Value (percent)"],
            },
            sorting = { "NONE", "PERCENT", "VALUE", "VALUE_MAX", "VALUE_PERCENT" },
        },
    },
})

-- The tooltip text ends about this far above the tooltip's bottom edge; the bottom padding makes
-- room for the bar below that.
local TEXT_BOTTOM_MARGIN = 10
-- Space between the last line and the bar.
local GAP = 2

-- The bar is a child of GameTooltip with a secure mixin; Blizzard feeds it (possibly secret) health
-- values. Nothing is stored on it: our regions and its original look live in these locals.
---@type StatusBar
local bar
---@type Texture, FontString
local background, text
---@type { texture: any, height: number, points: table[] }?
local original

function feature:OnInitialize()
    bar = GameTooltip.StatusBar
    if not bar then
        return
    end
    background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1)
    -- The unit frames' status text font.
    text =
        bar:CreateFontString(nil, "OVERLAY", _G.TextStatusBarText and "TextStatusBarText" or "GameFontHighlightSmall")
    text:SetPoint("CENTER")

    -- Unit and object tooltips show the bar (Blizzard's post-call, registered before ours).
    self:AddTooltipPostCall(Enum.TooltipDataType.Unit, "OnHealthTooltip")
    self:AddTooltipPostCall(Enum.TooltipDataType.Object, "OnHealthTooltip")
end

function feature:OnEnable()
    if not bar then
        return
    end
    if not original then
        local points = {}
        for i = 1, bar:GetNumPoints() do
            points[i] = { bar:GetPoint(i) }
        end
        original = { texture = bar:GetStatusBarTexture():GetTexture(), height = bar:GetHeight(), points = points }
    end
    background:Show()
    text:Show()
    self:ApplySettings()
    self:SecureHookScript(bar, "OnValueChanged", "UpdateText")
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")
end

function feature:OnDisable()
    if not bar or not original then
        return
    end
    LSM.UnregisterCallback(self, "LibSharedMedia_Registered")
    background:Hide()
    text:Hide()
    bar:SetStatusBarTexture(original.texture)
    bar:SetHeight(original.height)
    bar:ClearAllPoints()
    for _, point in ipairs(original.points) do
        bar:SetPoint(unpack(point))
    end
    GameTooltip:SetPadding(0, 0)
end

---@param mediaType string
---@param key string
function feature:OnMediaRegistered(_, mediaType, key)
    if mediaType == LSM.MediaType.STATUSBAR and key == self:Settings().texture then
        self:ApplySettings()
    end
end

function feature:ApplySettings()
    if not bar then
        return
    end
    local settings = self:Settings()
    bar:SetStatusBarTexture(media.Fetch(LSM.MediaType.STATUSBAR, settings.texture) or original.texture)
    bar:SetHeight(settings.height)
    local color = settings.backgroundColor
    background:SetVertexColor(color.r, color.g, color.b, color.a)
    self:Layout()
    self:UpdateText()
end

-- Inside: the bar sits at the bottom of the tooltip, `inset` from its edges, and the tooltip grows
-- by a bottom padding so its text ends above the bar. Outside: Blizzard's anchors below the tooltip.
-- The tooltip clears its padding when it hides, so this runs for every unit tooltip.
function feature:Layout()
    local settings = self:Settings()
    bar:ClearAllPoints()
    if settings.inside and bar:IsShown() then
        local inset = settings.inset
        bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", inset, inset)
        bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -inset, inset)
        GameTooltip:SetPadding(0, math.max(0, inset + settings.height + GAP - TEXT_BOTTOM_MARGIN))
    else
        for _, point in ipairs(original.points) do
            bar:SetPoint(unpack(point))
        end
        GameTooltip:SetPadding(0, 0)
    end
end

-- The tooltip lays itself out after the post-calls, so the padding set here is used right away.
---@param tooltip GameTooltip
function feature:OnHealthTooltip(tooltip)
    if tooltip == GameTooltip then
        self:Layout()
        self:UpdateText()
    end
end

-- Health values may be secret: they only go through the APIs that accept secrets from addon code
-- (AbbreviateNumbers, UnitHealthPercent with a curve, FontString:SetFormattedText) and are never
-- compared or computed with here. Objects (no unit) get no text.
function feature:UpdateText()
    local format = self:Settings().text
    local _, unit = GameTooltip:GetUnit()
    if format == "NONE" or not unit or anySecret(unit) or not bar:IsShown() then
        text:SetText("")
        return
    end
    local value = AbbreviateNumbers(UnitHealth(unit))
    local percent
    if UnitHealthPercent and CurveConstants then
        percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    elseif format ~= "VALUE_MAX" then
        -- No percent API: fall back to the value alone.
        format = "VALUE"
    end
    if format == "PERCENT" then
        text:SetFormattedText("%.0f%%", percent)
    elseif format == "VALUE" then
        text:SetFormattedText("%s", value)
    elseif format == "VALUE_MAX" then
        text:SetFormattedText(L["%s / %s"], value, AbbreviateNumbers(UnitHealthMax(unit)))
    else
        text:SetFormattedText(L["%s (%.0f%%)"], value, percent)
    end
end
