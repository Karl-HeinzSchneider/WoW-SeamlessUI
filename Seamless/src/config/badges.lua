---@type string, SeamlessCore
local _, app = ...
local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Match the native Settings tag anchors; the template sizes its text on show.
local GAP = 2

function config:UpdateFeatureTags(owner, anchor, tags)
    if not tags.new and not tags.blizzard and not owner.featureTags then
        return
    end
    local previous = anchor
    owner.featureTags = owner.featureTags or {}
    -- Nearest the label first. Both flags can be displayed independently.
    for _, key in ipairs({ "blizzard", "new" }) do
        local badge = owner.featureTags[key]
        if tags[key] then
            if not badge then
                -- Native Settings owns each tag on its row, with its own high strata.
                badge = CreateFrame("Frame", nil, owner, "NewFeatureLabelTemplate")
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
            badge:Show()
        elseif badge then
            badge:Hide()
        end
    end
end
