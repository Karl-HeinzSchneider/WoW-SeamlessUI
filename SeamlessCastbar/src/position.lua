---@type string, SeamlessCastbar
local appName, app = ...

-- Positions of the target and focus cast bars. The client places each bar under its unit frame
-- (TargetSpellBarMixin:AdjustPosition, also its OnShow script), below the auras or the ToT when
-- there are any. A moved bar keeps a position per Edit Mode layout in the profile; post-hooks on
-- AdjustPosition and OnShow put the bar there again whenever the client places it. The bar is
-- only anchored, never read: once the client anchors it to the aura container its geometry is
-- secret, so dragging happens on the addon-owned preview (preview.lua). A bar that was never
-- moved keeps the client's anchor; after a reset or disabling, the client's next placement (the
-- next cast or target change) puts it back. Nothing is stored on the bars and none of their
-- methods are called. A scale per layout (profile.scales) works the same way: the client never
-- scales the bars, so ours is set on every placement and 1 restores the client's.

local lib = app.core:GetEditModeLibrary()

---@class SeamlessCastbar.Position
---@field point string
---@field relativeTo string  # the global name of the frame it is anchored to
---@field relativePoint string
---@field x number  # in the bar's own scale, like SetPoint
---@field y number

local module = { active = false }
app.position = module

-- The bars this module moves, by profile key, in Frames list order.
module.keys = { "target", "focus" }
local specs = {
    target = { frame = "TargetFrame", bar = "TargetFrameSpellBar" },
    focus = { frame = "FocusFrame", bar = "FocusFrameSpellBar" },
}

---@param key string
---@return StatusBar? bar, Frame? unitFrame
function module:Frames(key)
    local spec = specs[key]
    return _G[spec.bar], _G[spec.frame]
end

function module:IsMovable(key)
    local bar, parent = self:Frames(key)
    return bar ~= nil and parent ~= nil
end

---The client's spot for the bar under its unit frame, without aura rows.
---@return SeamlessCastbar.Position
function module:Default(key)
    local _, parent = self:Frames(key)
    local small = parent and parent.smallSize
    local x, y = small and 38 or 43, small and 3 or 5
    if parent and parent.haveToT then
        y = small and -48 or -46
    end
    return {
        point = "TOPLEFT",
        relativeTo = parent and parent:GetName() or "UIParent",
        relativePoint = "BOTTOMLEFT",
        x = x,
        y = y,
    }
end

local function Stored(key)
    local layout = lib:GetActiveLayoutName()
    return layout and app.db.profile.positions[key][layout]
end

function module:IsMoved(key)
    return Stored(key) ~= nil
end

---The active layout's position, or the client's.
---@return SeamlessCastbar.Position
function module:Get(key)
    local stored = Stored(key)
    return stored and CopyTable(stored) or self:Default(key)
end

---A valid frame to anchor to; anything else (renamed, missing, a cycle) falls back to the unit frame.
---@return Frame
function module:RelativeFrame(key, name)
    local bar, parent = self:Frames(key)
    local target = type(name) == "string" and _G[name]
    if type(target) == "table" and target.IsObjectType and target:IsObjectType("Frame") then
        if app.core:GetFramePositionService():IsValidAnchorTarget(target, bar) then
            return target
        end
    end
    return parent or UIParent
end

local SCALE_MIN, SCALE_MAX = 0.5, 2

-- Bars whose scale this module changed, so a reset or disabling puts the client's back.
local scaled = {}

---The active layout's scale of the bar, 1 when unchanged.
---@return number
function module:GetScale(key)
    local layout = lib:GetActiveLayoutName()
    return layout and app.db.profile.scales[key][layout] or 1
end

---Change the scale in the active layout and keep the bar's anchor point where it is on screen.
function module:SetScale(key, value)
    local layout = lib:GetActiveLayoutName()
    if not layout or not self.active or type(value) ~= "number" then
        return
    end
    value = math.min(SCALE_MAX, math.max(SCALE_MIN, math.floor(value * 100 + 0.5) / 100))
    local old = self:GetScale(key)
    app.db.profile.scales[key][layout] = value ~= 1 and value or nil
    local stored = Stored(key)
    if stored then
        stored.x, stored.y = stored.x * old / value, stored.y * old / value
    end
    self:Apply(key)
    self:Changed()
end

---The Scale binding of the options tab and the Edit Mode slider.
---@return table
function module:ScaleOption(key)
    return {
        min = SCALE_MIN,
        max = SCALE_MAX,
        step = 0.01,
        default = 1,
        get = function()
            return self:GetScale(key)
        end,
        set = function(value)
            self:SetScale(key, value)
        end,
    }
end

-- Every part of the addon that shows a position: the options and the Edit Mode previews.
function module:Changed()
    app.core:RefreshOptions(appName)
    app.UpdatePreviews()
end

---Put a moved bar at its position. The bars are not protected, so this also works in combat,
---like the client's own placement.
---@param key string
function module:Apply(key)
    local bar = self:Frames(key)
    if not bar then
        return
    end
    local scale = self.active and self:GetScale(key) or 1
    if scale ~= 1 or scaled[bar] then
        bar:SetScale(scale)
        scaled[bar] = scale ~= 1 or nil
    end
    if not (self.active and self:IsMoved(key)) then
        return
    end
    local position = self:Get(key)
    bar:ClearAllPoints()
    bar:SetPoint(
        position.point,
        self:RelativeFrame(key, position.relativeTo),
        position.relativePoint,
        position.x,
        position.y
    )
end

function module:ApplyAll()
    for _, key in ipairs(self.keys) do
        self:Apply(key)
    end
    self:Changed()
end

---Store a whole position for the active layout, e.g. after a drag.
---@param position SeamlessCastbar.Position
function module:SetPosition(key, position)
    local layout = lib:GetActiveLayoutName()
    if not layout or not self.active then
        return
    end
    app.db.profile.positions[key][layout] = {
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

---Back to the client's anchor in the active layout, from its next placement on.
function module:Reset(key)
    local layout = lib:GetActiveLayoutName()
    if not layout then
        return
    end
    app.db.profile.positions[key][layout] = nil
    self:Changed()
end

---The bar's options tab Position and scale group; nil for bars that can't move.
---@param key string
---@return table?
function module:GetOptions(key)
    if not specs[key] then
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
            return not self.active or not self:IsMovable(key) or lib:GetActiveLayoutName() == nil
        end,
        anchorFrames = function()
            return app.core:GetFramePositionService():GetAnchorFrames((self:Frames(key)))
        end,
        scale = self:ScaleOption(key),
    })
end

-- Positions belong to a layout: follow the game's layout copies, renames and deletes in every
-- profile, like the moved ToT frames.
local function ForEachLayoutTable(callback)
    if app.db then
        for _, profile in pairs(app.db.profiles) do
            for _, field in ipairs({ "positions", "scales" }) do
                for _, layouts in pairs(profile[field] or {}) do
                    callback(layouts)
                end
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

-- From OnEnable, after the unit frames created their bars. The hooks run after the client placed
-- the bar, so a moved bar never shows at the client's spot. OnDisable's UnhookAll removes them.
function module:Enable()
    self.active = true
    for _, key in ipairs(self.keys) do
        local bar = self:Frames(key)
        if bar and bar.AdjustPosition then
            local function apply()
                self:Apply(key)
            end
            app.addon:SecureHook(bar, "AdjustPosition", apply)
            app.addon:SecureHookScript(bar, "OnShow", apply)
        end
    end
    self:ApplyAll()
end

function module:Disable()
    self.active = false
    for _, key in ipairs(self.keys) do
        self:Apply(key)
    end
    self:Changed()
end

function module:Refresh()
    if self.active then
        self:ApplyAll()
    end
end
