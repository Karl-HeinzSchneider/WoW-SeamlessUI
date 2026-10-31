---@type string, SeamlessCastbar
local _, app = ...

-- Keep native dimensions outside the frame so disabling or changing profiles restores them.
local nativeWidth, nativeHeight

function app.PlayerSizeDefault(axis)
    local bar = PlayerCastingBarFrame
    if axis == "width" then
        return nativeWidth or (bar and bar:GetWidth())
    end
    return nativeHeight or (bar and bar:GetHeight())
end

function app.ApplyPlayerSize()
    local bar = PlayerCastingBarFrame
    if not bar then
        return
    end
    local settings = app.db.profile.player
    local active = app.addon:IsEnabled() and settings.enabled
    if active and (settings.width or settings.height) then
        nativeWidth = nativeWidth or bar:GetWidth()
        nativeHeight = nativeHeight or bar:GetHeight()
        bar:SetWidth(settings.width or nativeWidth)
        bar:SetHeight(settings.height or nativeHeight)
    elseif nativeWidth then
        bar:SetWidth(nativeWidth)
        bar:SetHeight(nativeHeight)
        nativeWidth, nativeHeight = nil, nil
    end
end

-- SetLook has already restored both native dimensions when this post-hook runs.
function app.PlayerSizeLookChanged()
    nativeWidth, nativeHeight = nil, nil
    app.ApplyPlayerSize()
end
