---@type string, SeamlessCore
local _, app = ...
local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Match the native Settings tag anchors; the template sizes its text on show.
local GAP = 2

local function refreshOwner(owner)
    local visible = owner:IsVisible()
    local viewport, anchor = owner.featureTagViewport, owner.featureTagAnchor
    if visible and viewport then
        local top, bottom = anchor:GetTop(), anchor:GetBottom()
        local clipTop, clipBottom = viewport:GetTop(), viewport:GetBottom()
        visible = viewport:IsVisible() and top ~= nil and bottom ~= nil and clipTop ~= nil and clipBottom ~= nil
        if visible then
            local center = (top + bottom) / 2 * owner:GetEffectiveScale()
            local scale = viewport:GetEffectiveScale()
            visible = center <= clipTop * scale and center >= clipBottom * scale
        end
    end
    for _, badge in pairs(owner.featureTags) do
        badge:SetShown(visible and badge.tagEnabled)
    end
end

function config:RefreshFeatureTags()
    for owner in pairs(self.featureTagOwners or {}) do
        refreshOwner(owner)
    end
end

function config:CreateFeatureTagOverlay()
    if self.featureTagOverlay then
        return
    end
    local overlay = CreateFrame("Frame", nil, self.frame)
    self.featureTagOverlay = overlay
    self.featureTagOwners = setmetatable({}, { __mode = "k" })
    overlay:SetAllPoints()
    overlay:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    overlay:SetScript("OnUpdate", function()
        self:RefreshFeatureTags()
    end)
end

function config:UpdateFeatureTags(owner, anchor, tags)
    if not tags.new and not tags.blizzard and not owner.featureTags then
        return
    end
    self:CreateFeatureTagOverlay()
    local previous = anchor
    if not owner.featureTags then
        owner.featureTags = {}
        owner:HookScript("OnHide", function()
            for _, badge in pairs(owner.featureTags) do
                badge:Hide()
            end
        end)
    end
    self.featureTagOwners[owner] = true
    owner.featureTagAnchor = anchor
    -- Nearest the label first. Both flags can be displayed independently.
    for _, key in ipairs({ "blizzard", "new" }) do
        local badge = owner.featureTags[key]
        if tags[key] then
            if not badge then
                -- A sibling of both scroll containers, above the window artwork.
                -- Anchoring to a scrolled label follows its position without inheriting clipping.
                badge = CreateFrame("Frame", nil, self.featureTagOverlay, "NewFeatureLabelTemplate")
                owner.featureTags[key] = badge
                badge.ignoreInLayout = true
                badge:EnableMouse(false)
                badge:SetSize(1, 1)
                badge:SetScale(0.8)
                badge:SetFrameStrata("HIGH")
                badge:SetFrameLevel(100)
                if key == "blizzard" then
                    badge.Label:SetTextToFit(L["BLIZZ"])
                    badge.BGLabel:SetTextToFit(L["BLIZZ"])
                end
            end
            badge.tagEnabled = true
            badge:ClearAllPoints()
            if previous == anchor then
                local category = owner.text == anchor
                badge:SetPoint("BOTTOMRIGHT", anchor, "LEFT", category and -4 or 16, -10)
                if category then
                    badge.Label:ClearAllPoints()
                    badge.BGLabel:ClearAllPoints()
                    badge.Label:SetPoint("RIGHT", 0, 0)
                    badge.BGLabel:SetPoint("RIGHT", 0.5, -0.5)
                else
                    badge.Label:ClearAllPoints()
                    badge.BGLabel:ClearAllPoints()
                    badge.Label:SetPoint("CENTER")
                    badge.BGLabel:SetPoint("CENTER", 0.5, -0.5)
                end
            else
                -- Keep a second tag clear of the first tag's rendered text.
                badge:SetPoint("RIGHT", previous.Label, "LEFT", -GAP / 0.8, 0)
                badge.Label:ClearAllPoints()
                badge.BGLabel:ClearAllPoints()
                badge.Label:SetPoint("RIGHT", 0, 0)
                badge.BGLabel:SetPoint("RIGHT", 0.5, -0.5)
            end
            previous = badge
        elseif badge then
            badge.tagEnabled = false
        end
    end
    refreshOwner(owner)
end
