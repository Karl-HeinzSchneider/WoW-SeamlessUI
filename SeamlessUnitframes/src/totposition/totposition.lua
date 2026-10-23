---@type string, SeamlessUnitframes
local appName, app = ...

-- Positions of the target of target and target of focus frames. Neither has an Edit Mode system:
-- the client creates them as secure children of their unit frame (TargetFrameMixin:
-- CreateTargetofTarget) and anchors them below it. A moved frame keeps a position per Edit Mode
-- layout in the profile; this module puts the real frame there, only out of combat, with nothing
-- stored on the secure frame and its scripts untouched. A frame that was never moved keeps the
-- client's anchor. Dragging happens on an addon-owned stand-in (mover.lua).

local lib = app.core:GetEditModeLibrary()

---@class SeamlessUnitframes.ToTPosition.Position
---@field point string
---@field relativeTo string  # the global name of the frame it is anchored to
---@field relativePoint string
---@field x number  # in the frame's own scale, like SetPoint
---@field y number

---@class SeamlessUnitframes.ToTPosition : AceModule, AceEvent-3.0
---@field active? boolean
---@field pending? boolean  # an apply waits for combat to end
---@field focusHooked? boolean
local module = {}
app.totPosition = app.addon:NewModule("ToTPosition", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.ToTPosition]]

-- The registry keys of the frames this module moves, in Frames list order.
module.keys = { "targettarget", "focustarget" }

-- Frames whose anchor this module changed, so disabling or a reset puts the client's back.
local applied = {}

-- The client's anchor (TargetofTargetFrameTemplate; FocusFrameMixin:SetSmallSize for focus).
local function ClientOffsets(parent)
    if parent == FocusFrame and FocusFrame.smallSize then
        return 20, 8
    end
    return 12, 10
end

---@param key string
---@return Frame? frame, Frame? parent
function module:Frames(key)
    local entry = app.unitFrames:Get(key)
    return _G[entry.frameName], _G[app.unitFrames:Get(entry.linkedTo).frameName]
end

function module:IsMovable(key)
    for _, movable in ipairs(self.keys) do
        if movable == key then
            local frame, parent = self:Frames(key)
            return frame ~= nil and parent ~= nil
        end
    end
    return false
end

---The client's position: below the unit frame it belongs to.
---@return SeamlessUnitframes.ToTPosition.Position
function module:Default(key)
    local _, parent = self:Frames(key)
    local x, y = ClientOffsets(parent)
    return {
        point = "TOPRIGHT",
        relativeTo = parent and parent:GetName() or "UIParent",
        relativePoint = "BOTTOMRIGHT",
        x = x,
        y = y,
    }
end

local function Stored(key)
    local layout = lib:GetActiveLayoutName()
    return layout and app.db.profile.totPositions[key][layout]
end

function module:IsMoved(key)
    return Stored(key) ~= nil
end

---The active layout's position, or the client's.
---@return SeamlessUnitframes.ToTPosition.Position
function module:Get(key)
    local stored = Stored(key)
    return stored and CopyTable(stored) or self:Default(key)
end

---A valid frame to anchor to; anything else (renamed, missing, a cycle) falls back to the unit frame.
---@return Frame
function module:RelativeFrame(key, name)
    local frame, parent = self:Frames(key)
    local target = type(name) == "string" and _G[name]
    local service = app.core:GetFramePositionService()
    if type(target) == "table" and target.IsObjectType and target:IsObjectType("Frame") then
        if service:IsValidAnchorTarget(target, frame) then
            return target
        end
    end
    return parent or UIParent
end

-- Every part of the addon that shows a position: the options and the Edit Mode stand-ins.
function module:Changed()
    app.core:RefreshOptions(appName)
    app.totMover:Refresh()
end

---@param key string
function module:Apply(key)
    local frame = self:Frames(key)
    if not frame or not (self.active and self:IsMoved(key)) and not applied[frame] then
        return
    end
    if InCombatLockdown() then
        self.pending = true
        return
    end
    local position = self.active and self:Get(key) or self:Default(key)
    frame:ClearAllPoints()
    frame:SetPoint(
        position.point,
        self:RelativeFrame(key, position.relativeTo),
        position.relativePoint,
        position.x,
        position.y
    )
    applied[frame] = self.active and self:IsMoved(key) or nil
end

function module:ApplyAll()
    self.pending = nil
    for _, key in ipairs(self.keys) do
        self:Apply(key)
    end
    self:Changed()
end

---Store a whole position for the active layout, e.g. after a drag.
---@param position SeamlessUnitframes.ToTPosition.Position
function module:SetPosition(key, position)
    local layout = lib:GetActiveLayoutName()
    if not layout or not self.active or InCombatLockdown() then
        return
    end
    app.db.profile.totPositions[key][layout] = {
        point = position.point,
        relativeTo = position.relativeTo,
        relativePoint = position.relativePoint,
        x = position.x,
        y = position.y,
    }
    self:Apply(key)
    self:Changed()
end

---Change one field (point, relativeTo, relativePoint, x or y), starting from the current position.
function module:Set(key, field, value)
    local position = self:Get(key)
    position[field] = value
    self:SetPosition(key, position)
end

---Back to the client's anchor in the active layout.
function module:Reset(key)
    local layout = lib:GetActiveLayoutName()
    if not layout or InCombatLockdown() then
        return
    end
    app.db.profile.totPositions[key][layout] = nil
    self:Apply(key)
    self:Changed()
end

---The Position and scale group for the frame's options tab; nil for other frames. Scale stays
---disabled: these frames take their unit frame's Frame Size.
---@param key string
---@return table?
function module:GetOptions(key)
    if not self:IsMovable(key) then
        return nil
    end
    return app.core:GetPositionOptions({
        get = function(field)
            return self:Get(key)[field]
        end,
        set = function(field, value)
            self:Set(key, field, value)
        end,
        default = function(field)
            return self:Default(key)[field]
        end,
        isDefault = function()
            return not self:IsMoved(key)
        end,
        reset = function()
            self:Reset(key)
        end,
        disabled = function()
            return not self.active or lib:GetActiveLayoutName() == nil
        end,
        anchorFrames = function()
            return app.core:GetFramePositionService():GetAnchorFrames(self:Frames(key))
        end,
    })
end

-- Positions belong to a layout: follow the game's layout copies, renames and deletes in every
-- profile, like the FPS display.
local function ForEachLayoutTable(callback)
    if app.db then
        for _, profile in pairs(app.db.profiles) do
            for _, layouts in pairs(profile.totPositions or {}) do
                callback(layouts)
            end
        end
    end
end

lib:RegisterCallback("create", function(name, _, sourceName)
    ForEachLayoutTable(function(layouts)
        local source = sourceName and layouts[sourceName]
        layouts[name] = source and CopyTable(source) or nil
    end)
end)
lib:RegisterCallback("rename", function(oldName, newName)
    ForEachLayoutTable(function(layouts)
        layouts[newName], layouts[oldName] = layouts[oldName], nil
    end)
end)
lib:RegisterCallback("delete", function(name)
    ForEachLayoutTable(function(layouts)
        layouts[name] = nil
    end)
end)
lib:RegisterCallback("layout", function()
    if module.active then
        module:ApplyAll()
    end
end)

function module:OnEnable()
    self.active = true
    app.totMover:Register()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.pending then
            self:ApplyAll()
        end
    end)
    -- Toggling Larger Frame re-anchors and rescales the focus ToT; put a moved one back.
    if not self.focusHooked and FocusFrame and FocusFrame.SetSmallSize then
        self.focusHooked = true
        hooksecurefunc(FocusFrame, "SetSmallSize", function()
            if self.active then
                self:Apply("focustarget")
                self:Changed()
            end
        end)
    end
    self:ApplyAll()
end

function module:OnDisable()
    self.active = false
    self:ApplyAll()
end

function module:OnProfileRefresh()
    if self.active then
        self:ApplyAll()
    end
end
