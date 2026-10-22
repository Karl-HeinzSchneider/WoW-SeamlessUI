---@type string, SeamlessUnitframes
local appName, app = ...

-- Edit Mode stand-ins for the target of target and target of focus frames. The real frames are
-- secure buttons that hide without a unit and must not be dragged (StartMoving saves them in the
-- client's layout cache) or turned into Edit Mode systems. Each stand-in is an addon-owned
-- UIParent child with the frame's art, size and effective scale, registered with LibEditMode and
-- shown only in Edit Mode. Dragging it, its Position section or Reset Position store a position
-- through app.totPosition, which then moves the real frame.

local lib = app.core:GetEditModeLibrary()

-- TargetofTargetFrameTemplate's size and border art.
local WIDTH, HEIGHT = 120, 49
local ART = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn"

-- LibEditMode's Reset Position reports the registered default through the same callback as a
-- drag. No drag ends exactly on this point, so it means "back to the client's anchor".
local RESET = { point = "CENTER", x = 0, y = 0 }

---@class SeamlessUnitframes.ToTMover
---@field movers table<string, Frame>
---@field shown table<string, boolean>  # the Frames list checkboxes, on for the session
local mover = { movers = {}, shown = {} }
app.totMover = mover

local function Known(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function IsReset(point, x, y)
    return point == RESET.point and x == RESET.x and y == RESET.y
end

-- LibEditMode anchored the stand-in to UIParent; keep the stored point and anchor frame and
-- measure the new offsets from there, so a ToT anchored to its unit frame stays attached to it.
local function OnMoved(key, point, x, y)
    local position = app.totPosition
    if IsReset(point, x, y) then
        position:Reset(key)
        return
    end
    local current = position:Get(key)
    local relative = position:RelativeFrame(key, current.relativeTo)
    local offsetX, offsetY = position:MeasureOffsets(mover.movers[key], current.point, relative, current.relativePoint)
    if offsetX then
        current.relativeTo, current.x, current.y = relative:GetName(), offsetX, offsetY
    else
        current.point, current.relativeTo, current.relativePoint, current.x, current.y = point, "UIParent", point, x, y
    end
    position:SetPosition(key, current)
end

---@param key string
local function Create(key)
    local entry = app.unitFrames:Get(key)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetClampedToScreen(true)
    local art = frame:CreateTexture(nil, "ARTWORK")
    art:SetAtlas(ART, true)
    art:SetPoint("CENTER")
    lib:AddFrame(frame, function(_, _, point, x, y)
        OnMoved(key, point, x, y)
    end, RESET, entry.name)
    local position = app.totPosition
    lib:AddFrameSettings(
        frame,
        app.core:GetEditModePositionSettings({
            get = function(field)
                return position:Get(key)[field]
            end,
            set = function(field, value)
                position:Set(key, field, value)
            end,
            anchorFrames = function()
                return app.core:GetFramePositionService():GetAnchorFrames((position:Frames(key)))
            end,
            disabled = function()
                return not position.active
            end,
        })
    )
    mover.movers[key] = frame
    mover.shown[key] = true
end

-- Place each stand-in where the real frame is or would be, at its effective scale.
function mover:Refresh()
    local position = app.totPosition
    for key, frame in pairs(self.movers) do
        local real = position:Frames(key)
        local visible = position.active and lib:IsInEditMode() and self.shown[key] and real ~= nil
        if visible then
            local scale = real:GetEffectiveScale()
            local parentScale = UIParent:GetEffectiveScale()
            frame:SetScale(Known(scale) and scale / parentScale or 1)
            local current = position:Get(key)
            frame:ClearAllPoints()
            frame:SetPoint(
                current.point,
                position:RelativeFrame(key, current.relativeTo),
                current.relativePoint,
                current.x,
                current.y
            )
            lib:RefreshFrameSettings(frame)
        end
        frame:SetShown(visible or false)
    end
end

local registered = false

-- Once, from the addon's OnEnable: the client creates the ToT frames with their unit frames.
function mover:Register()
    if registered then
        return
    end
    registered = true
    local options = {}
    for _, key in ipairs(app.totPosition.keys) do
        if app.totPosition:IsMovable(key) then
            Create(key)
            options[#options + 1] = {
                key = key,
                type = "toggle",
                name = app.unitFrames:Get(key).name,
                get = function()
                    return self.shown[key]
                end,
                set = function(value)
                    self.shown[key] = value
                    EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                    self:Refresh()
                end,
            }
        end
    end
    app.core:RegisterEditModeOptions(appName .. ".ToT", {
        section = "frames",
        enabled = function()
            return app.totPosition.active == true
        end,
        options = options,
    })
    lib:RegisterCallback("enter", function()
        self:Refresh()
    end)
    lib:RegisterCallback("exit", function()
        self:Refresh()
    end)
end
