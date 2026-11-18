---@type string, SeamlessCastbar
local _, app = ...

function app.PlayerSizeDefault(axis)
    return app.dbDefaults.profile.player[axis]
end

---@param bar StatusBar
function app.ApplyPlayerTextLayout(bar)
    local settings = app.db.profile.player
    local name, time, border = bar.Text, bar.CastTimeText, bar.TextBorder
    if not name then
        return
    end
    name:ClearAllPoints()
    if time then
        time:ClearAllPoints()
    end
    if border then
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, settings.compactLayout and -16 or -12)
    end
    if settings.compactLayout then
        local width = settings.width or app.PlayerSizeDefault("width")
        local inset = math.min(5, width * 0.1)
        name:SetWidth(0)
        name:SetJustifyH("LEFT")
        name:SetPoint("LEFT", bar, "BOTTOMLEFT", inset, -8)
        local nameRight = inset
        if time then
            time:SetFontObject(name:GetFontObject())
            time:SetJustifyH("RIGHT")
            time:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -inset, -8)
            -- The timer's rendered width can be secret. Size both columns from the
            -- profile and anchor them directly to our bar.
            local timeWidth = math.min(100, width * 0.45)
            time:SetWidth(timeWidth)
            if settings.showCastTime then
                nameRight = inset * 2 + timeWidth
            end
        end
        name:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -nameRight, -8)
    else
        -- CastingBarFrame.lua SetLook("CLASSIC") and CastingBarFrameTemplate in the client XML.
        -- Keep the name bottom-relative when the configured bar height changes.
        name:SetWidth(185)
        name:SetJustifyH("CENTER")
        name:SetPoint("TOP", bar, "BOTTOM", 0, bar.classicStyleCastBar and 18 or 1)
        if time then
            time:SetWidth(0)
            time:SetJustifyH("CENTER")
            time:SetFontObject("GameFontHighlightLarge")
            time:SetPoint("LEFT", bar, "RIGHT", 10, 0)
        end
    end
end

function app.ApplyPlayerSize()
    local bar = app.GetPlayerBar()
    if not bar or not app.addon:IsEnabled() then
        return
    end
    local settings = app.db.profile.player
    local width = settings.width or app.PlayerSizeDefault("width")
    bar:SetScale(settings.scale or app.PlayerSizeDefault("scale"))
    bar:SetWidth(width)
    bar:SetHeight(settings.height or app.PlayerSizeDefault("height"))
    if bar.BorderMask then
        -- The native mask clips the cast trail but has a fixed width (CastingBarFrame.xml).
        bar.BorderMask:SetWidth(width)
    end
    if bar.InterruptGlow then
        -- The native InterruptGlow uses a fixed atlas size and half scale.
        -- Fit it to the resized bar with a small margin for the glow.
        local glow = bar.InterruptGlow
        glow:SetScale(1)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
        glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
    end
    if bar.Icon then
        local size = settings.iconSize or app.PlayerSizeDefault("iconSize")
        bar.Icon:SetSize(size, size)
    end
    app.ApplyPlayerTextLayout(bar)
end
