---@type string, SeamlessCore
local _, app = ...
local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The native label is 40x20; scale it to 32x16 to fit our 20-pixel list rows.
local WIDTH, GAP, LABEL_GAP = 32, 2, 4
function config:GetFeatureTagWidth(tags)
    local count = (tags.new and 1 or 0) + (tags.blizzard and 1 or 0)
    return count > 0 and count * WIDTH + (count - 1) * GAP + LABEL_GAP or 0
end

function config:UpdateFeatureTags(owner, anchor, tags)
    local previous = anchor
    owner.featureTags = owner.featureTags or {}
    -- Nearest the label first. Both flags can be displayed independently.
    for _, key in ipairs({ "blizzard", "new" }) do
        local badge = owner.featureTags[key]
        if tags[key] then
            if not badge then
                badge = CreateFrame("Frame", nil, owner, "NewFeatureLabelNoAnimateTemplate")
                owner.featureTags[key] = badge
                badge:SetSize(40, 20)
                badge:SetScale(0.8)
                if key == "blizzard" then
                    badge.Label:SetTextToFit(L["BLIZZ"])
                    badge.BGLabel:SetTextToFit(L["BLIZZ"])
                end
            end
            badge:ClearAllPoints()
            badge:SetPoint("RIGHT", previous, "LEFT", -(previous == anchor and LABEL_GAP or GAP) / 0.8, 0)
            badge:Show()
            previous = badge
        elseif badge then
            badge:Hide()
        end
    end
end
