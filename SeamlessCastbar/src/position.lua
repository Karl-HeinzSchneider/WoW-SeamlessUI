---@type string, SeamlessCastbar
local appName, app = ...

local lib = app.core:GetEditModeLibrary()
local parents = { target = "TargetFrame", focus = "FocusFrame" }
local originalScales, scaled = {}, {}

-- Defaults describe our readable preview, never the potentially secret live bar geometry.
local function defaultPosition(key)
    local parent = _G[parents[key]]
    local small = parent and parent.smallSize
    return {
        point = "TOPLEFT",
        relativeTo = parents[key],
        relativePoint = "BOTTOMLEFT",
        x = small and 38 or 43,
        y = parent and parent.haveToT and (small and -48 or -46) or (small and 3 or 5),
    }
end

function app.CastbarPosition(key, useDefault)
    local saved = not useDefault and app.db.profile[key].position
    if not saved then
        return defaultPosition(key)
    end
    -- Positions saved by the original drag-only mover were relative to UIParent.
    return {
        point = saved.point,
        relativeTo = saved.relativeTo or "UIParent",
        relativePoint = saved.relativePoint or saved.point,
        x = saved.x,
        y = saved.y,
    }
end

local function changed(key)
    app.UpdatePreviews()
    app.core:RefreshOptions(appName)
    local preview = app.PreviewFrame(key)
    if preview then
        lib:RefreshFrameSettings(preview)
    end
end

-- Scale is a multiplier of the live bar's original local scale. Its parent still supplies
-- the unit-frame scale; never multiply the live scale repeatedly on refresh/show.
function app.ApplyCastbarScale(key, bar)
    local current = bar:GetScale()
    if not app.Known(current) then
        return
    end
    originalScales[key] = originalScales[key] or current
    local settings = app.db.profile[key]
    local active = app.addon:IsEnabled() and settings.enabled
    local multiplier = active and (settings.scale or 1) or 1
    if multiplier ~= 1 or scaled[key] then
        local value = originalScales[key] * multiplier
        if current ~= value then
            bar:SetScale(value)
        end
        scaled[key] = multiplier ~= 1 or nil
    end
end

function app.CastbarPositionSpec(key)
    local function disabled()
        return not app.addon:IsEnabled() or not app.db.profile[key].enabled
    end
    return {
        get = function(field)
            return app.CastbarPosition(key)[field]
        end,
        set = function(field, value)
            if disabled() or InCombatLockdown() then
                return
            end
            local position = app.CastbarPosition(key)
            position[field] = value
            app.db.profile[key].position = position
            changed(key)
        end,
        default = function(field)
            return defaultPosition(key)[field]
        end,
        reset = function()
            app.ResetCastbarPosition(key)
        end,
        isDefault = function()
            return app.db.profile[key].position == nil
        end,
        disabled = disabled,
        anchorFrames = function()
            return app.core:GetFramePositionService():GetAnchorFrames(app.PreviewFrame(key))
        end,
        scale = {
            default = 1,
            get = function()
                return app.db.profile[key].scale or 1
            end,
            set = function(value)
                if
                    disabled()
                    or InCombatLockdown()
                    or type(value) ~= "number"
                    or value ~= value
                    or value < 0.5
                    or value > 2
                then
                    return
                end
                app.db.profile[key].scale = value
                changed(key)
            end,
        },
    }
end

-- Preserve the selected anchor and point after a drag by measuring only the preview and
-- its chosen anchor frame. Fall back to the library's UIParent coordinates if unavailable.
function app.SaveCastbarDrag(key, point, x, y)
    if InCombatLockdown() or not app.addon:IsEnabled() or not app.db.profile[key].enabled then
        return
    end
    local position = app.CastbarPosition(key)
    local preview, relative = app.PreviewFrame(key), _G[position.relativeTo]
    local function at(frame, anchor)
        local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
        local scale = frame:GetEffectiveScale()
        if not (app.Known(left) and app.Known(right) and app.Known(top) and app.Known(bottom) and app.Known(scale)) then
            return
        end
        local px = anchor:find("LEFT") and left or anchor:find("RIGHT") and right or (left + right) / 2
        local py = anchor:find("TOP") and top or anchor:find("BOTTOM") and bottom or (top + bottom) / 2
        return px * scale, py * scale
    end
    local fx, fy = at(preview, position.point)
    local rx, ry
    if relative then
        rx, ry = at(relative, position.relativePoint)
    end
    if fx and rx then
        local scale = preview:GetEffectiveScale()
        position.x, position.y = (fx - rx) / scale, (fy - ry) / scale
    else
        position = { point = point, relativeTo = "UIParent", relativePoint = point, x = x, y = y }
    end
    app.db.profile[key].position = position
    changed(key)
end
