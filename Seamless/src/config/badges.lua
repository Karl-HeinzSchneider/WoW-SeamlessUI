---@type string, SeamlessCore
local _, app = ...
local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The native label is 40x20; scale it to 32x16 to fit our 20-pixel list rows.
local GAP, LABEL_GAP = 2, 4

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
                badge = CreateFrame("Frame", nil, self.featureTagOverlay, "NewFeatureLabelNoAnimateTemplate")
                owner.featureTags[key] = badge
                badge.ignoreInLayout = true
                badge:EnableMouse(false)
                badge:SetSize(40, 20)
                badge:SetScale(0.8)
                if key == "blizzard" then
                    badge.Label:SetTextToFit(L["BLIZZ"])
                    badge.BGLabel:SetTextToFit(L["BLIZZ"])
                end
            end
            badge.tagEnabled = true
            badge:ClearAllPoints()
            badge:SetPoint("RIGHT", previous, "LEFT", -(previous == anchor and LABEL_GAP or GAP) / 0.8, 0)
            previous = badge
        elseif badge then
            badge.tagEnabled = false
        end
    end
    refreshOwner(owner)
end
