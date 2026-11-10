---@type string, SeamlessCastbar
local _, app = ...

-- Capture native values only for restoration when overrides are inactive, never as defaults.
local states = {}

local function stateFor(bar)
    states[bar] = states[bar] or {}
    return states[bar]
end

local function resizePlayerIcon(bar, size)
    local state = stateFor(bar)
    local icon = bar.Icon
    if not icon then
        return
    end
    if size then
        state.nativeIconWidth = state.nativeIconWidth or icon:GetWidth()
        state.nativeIconHeight = state.nativeIconHeight or icon:GetHeight()
        icon:SetSize(size, size)
    elseif state.nativeIconWidth then
        icon:SetSize(state.nativeIconWidth, state.nativeIconHeight)
        state.nativeIconWidth, state.nativeIconHeight = nil, nil
    end
end

local function anchorPlayerText(bar, resize, height)
    local state = stateFor(bar)
    local text = bar.Text
    if not text then
        return
    end
    if resize and not state.nativeTextPoints then
        local count = text:GetNumPoints()
        if not app.Known(count) or not app.Known(height) then
            return
        end
        local points = {}
        for index = 1, count do
            local anchor, relativeTo, relativePoint, x, y = text:GetPoint(index)
            -- Native layout updates can expose secret anchors. Capture all points before
            -- changing any of them, and retry on a later refresh when they are readable.
            if
                not app.Known(anchor)
                or not app.Known(relativeTo)
                or not app.Known(relativePoint)
                or not app.Known(x)
                or not app.Known(y)
            then
                return
            end
            points[index] = { anchor, relativeTo, relativePoint, x, y }
        end
        state.nativeTextPoints = points
    end
    if not state.nativeTextPoints then
        return
    end
    text:ClearAllPoints()
    for _, point in ipairs(state.nativeTextPoints) do
        local anchor, relativeTo, relativePoint, x, y = unpack(point)
        if resize and app.Known(height) and relativeTo == bar and relativePoint:find("TOP", 1, true) then
            -- At native height this is the identical position, measured from the bottom.
            relativePoint = relativePoint:gsub("TOP", "BOTTOM")
            y = y + height
        end
        text:SetPoint(anchor, relativeTo, relativePoint, x, y)
    end
    if not resize then
        state.nativeTextPoints = nil
    end
end

function app.PlayerSizeDefault(axis)
    return app.dbDefaults.profile.player[axis]
end

function app.ApplyPlayerSize(bar)
    bar = bar or PlayerCastingBarFrame
    if not bar then
        return
    end
    local state = stateFor(bar)
    local settings = app.db.profile.player
    local active = app.addon:IsEnabled()
    resizePlayerIcon(bar, active and settings.iconSize)
    anchorPlayerText(bar, active and settings.height ~= nil, state.nativeHeight or bar:GetHeight())
    if active and settings.scale then
        state.nativeScale = state.nativeScale or bar:GetScale()
        bar:SetScale(settings.scale)
    elseif state.nativeScale then
        bar:SetScale(state.nativeScale)
        state.nativeScale = nil
    end
    if active and (settings.width or settings.height) then
        state.nativeWidth = state.nativeWidth or bar:GetWidth()
        state.nativeHeight = state.nativeHeight or bar:GetHeight()
        bar:SetWidth(settings.width or state.nativeWidth)
        bar:SetHeight(settings.height or state.nativeHeight)
    elseif state.nativeWidth then
        bar:SetWidth(state.nativeWidth)
        bar:SetHeight(state.nativeHeight)
        state.nativeWidth, state.nativeHeight = nil, nil
    end
end

-- The native Bar Size update also runs when locking the bar or changing layouts.
function app.PlayerScaleChanged(bar)
    bar = bar or PlayerCastingBarFrame
    local state = stateFor(bar)
    state.nativeScale = nil
    app.ApplyPlayerSize(bar)
end

-- SetLook has already restored both native dimensions when this post-hook runs.
function app.PlayerSizeLookChanged(bar)
    bar = bar or PlayerCastingBarFrame
    local state = stateFor(bar)
    state.nativeWidth, state.nativeHeight = nil, nil
    state.nativeTextPoints = nil
    app.ApplyPlayerSize(bar)
end
