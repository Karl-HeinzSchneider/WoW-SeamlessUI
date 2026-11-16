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
        name:SetWidth(0)
        name:SetJustifyH("LEFT")
        name:SetPoint("LEFT", bar, "BOTTOMLEFT", 5, -8)
        if time then
            time:SetFontObject(name:GetFontObject())
            time:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -5, -8)
        end
        if time and settings.showCastTime then
            name:SetPoint("RIGHT", time, "LEFT", -4, 0)
        else
            name:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -5, -8)
        end
    else
        -- CastingBarFrame.lua SetLook("CLASSIC") and CastingBarFrameTemplate in the client XML.
        -- Keep the name bottom-relative when the configured bar height changes.
        name:SetWidth(185)
        name:SetJustifyH("CENTER")
        name:SetPoint("TOP", bar, "BOTTOM", 0, bar.classicStyleCastBar and 18 or 1)
        if time then
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
    bar:SetScale(settings.scale or app.PlayerSizeDefault("scale"))
    bar:SetWidth(settings.width or app.PlayerSizeDefault("width"))
    bar:SetHeight(settings.height or app.PlayerSizeDefault("height"))
    if bar.Icon then
        local size = settings.iconSize or app.PlayerSizeDefault("iconSize")
        bar.Icon:SetSize(size, size)
    end
    app.ApplyPlayerTextLayout(bar)
end
