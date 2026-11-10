---@type string, SeamlessCastbar
local _, app = ...

function app.PlayerSizeDefault(axis)
    return app.dbDefaults.profile.player[axis]
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
    if bar.Text then
        -- Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua, SetLook("CLASSIC"):
        -- modern text is TOP -10 on an 11-high bar; classic text is TOP 5 on 13.
        -- Keep that bottom-relative placement without measuring live frame geometry.
        local y = bar.classicStyleCastBar and 18 or 1
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("TOP", bar, "BOTTOM", 0, y)
    end
end
