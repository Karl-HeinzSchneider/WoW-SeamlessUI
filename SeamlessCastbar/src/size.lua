---@type string, SeamlessCastbar
local _, app = ...

-- Capture native values only for restoration when overrides are inactive, never as defaults.
local nativeWidth, nativeHeight
local nativeScale
local nativeTextPoints
local nativeIconWidth, nativeIconHeight

local function resizePlayerIcon(bar, size)
    local icon = bar.Icon
    if not icon then
        return
    end
    if size then
        nativeIconWidth = nativeIconWidth or icon:GetWidth()
        nativeIconHeight = nativeIconHeight or icon:GetHeight()
        icon:SetSize(size, size)
    elseif nativeIconWidth then
        icon:SetSize(nativeIconWidth, nativeIconHeight)
        nativeIconWidth, nativeIconHeight = nil, nil
    end
end

local function anchorPlayerText(bar, resize, height)
    local text = bar.Text
    if not text then
        return
    end
    if resize and not nativeTextPoints then
        nativeTextPoints = {}
        for index = 1, text:GetNumPoints() do
            nativeTextPoints[index] = { text:GetPoint(index) }
        end
    end
    if not nativeTextPoints then
        return
    end
    text:ClearAllPoints()
    for _, point in ipairs(nativeTextPoints) do
        local anchor, relativeTo, relativePoint, x, y = unpack(point)
        if resize and relativeTo == bar and relativePoint:find("TOP", 1, true) then
            -- At native height this is the identical position, measured from the bottom.
            relativePoint = relativePoint:gsub("TOP", "BOTTOM")
            y = y + height
        end
        text:SetPoint(anchor, relativeTo, relativePoint, x, y)
    end
    if not resize then
        nativeTextPoints = nil
    end
end

function app.PlayerSizeDefault(axis)
    return app.dbDefaults.profile.player[axis]
end

function app.ApplyPlayerSize()
    local bar = PlayerCastingBarFrame
    if not bar then
        return
    end
    local settings = app.db.profile.player
    local active = app.addon:IsEnabled() and settings.enabled
    resizePlayerIcon(bar, active and settings.iconSize)
    anchorPlayerText(bar, active and settings.height ~= nil, nativeHeight or bar:GetHeight())
    if active and settings.scale then
        nativeScale = nativeScale or bar:GetScale()
        bar:SetScale(settings.scale)
    elseif nativeScale then
        bar:SetScale(nativeScale)
        nativeScale = nil
    end
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

-- The native Bar Size update also runs when locking the bar or changing layouts.
function app.PlayerScaleChanged()
    nativeScale = nil
    app.ApplyPlayerSize()
end

-- SetLook has already restored both native dimensions when this post-hook runs.
function app.PlayerSizeLookChanged()
    nativeWidth, nativeHeight = nil, nil
    nativeTextPoints = nil
    app.ApplyPlayerSize()
end
