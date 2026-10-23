---@type string, SeamlessCore
local _, app = ...
local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Match the native Settings tag anchors; the template sizes its text on show.
local GAP = 2

local LABELS = { blizzard = "BLIZZ", editMode = "EDIT MODE" }
-- Edit Mode's own selection blue, so the layout tag reads apart from NEW.
local GLOW = { editMode = { 0.3, 0.75, 1 } }

local function anchorText(badge, point)
    badge.Label:ClearAllPoints()
    badge.BGLabel:ClearAllPoints()
    badge.Label:SetPoint(point, 0, 0)
    badge.BGLabel:SetPoint(point, 0.5, -0.5)
end

-- Tags sit left of the label, in its inset; set `owner.tagTrailing` to put them right of
-- the label's text instead (section headings have no inset to hold them).
function config:UpdateFeatureTags(owner, anchor, tags)
    if not tags.new and not tags.blizzard and not tags.editMode and not owner.featureTags then
        return
    end
    local previous = anchor
    owner.featureTags = owner.featureTags or {}
    -- Nearest the label first. Each flag is displayed independently.
    for _, key in ipairs({ "editMode", "blizzard", "new" }) do
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
                if LABELS[key] then
                    badge.Label:SetTextToFit(L[LABELS[key]])
                    badge.BGLabel:SetTextToFit(L[LABELS[key]])
                end
                if GLOW[key] then
                    badge.Glow:SetVertexColor(unpack(GLOW[key]))
                end
            end
            badge:ClearAllPoints()
            if owner.tagTrailing then
                if previous == anchor then
                    local width = math.min(anchor:GetStringWidth(), anchor:GetWidth())
                    badge:SetPoint("LEFT", anchor, "LEFT", (width + 8) / 0.8, 0)
                else
                    badge:SetPoint("LEFT", previous.Label, "RIGHT", GAP / 0.8, 0)
                end
                anchorText(badge, "LEFT")
            elseif previous == anchor then
                local category = owner.text == anchor
                badge:SetPoint("BOTTOMRIGHT", anchor, "LEFT", category and -4 or 16, -10)
                anchorText(badge, category and "RIGHT" or "CENTER")
            else
                -- Keep a second tag clear of the first tag's rendered text.
                badge:SetPoint("RIGHT", previous.Label, "LEFT", -GAP / 0.8, 0)
                anchorText(badge, "RIGHT")
            end
            previous = badge
            badge:Show()
        elseif badge then
            badge:Hide()
        end
    end
end
