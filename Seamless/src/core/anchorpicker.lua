---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Edit Mode's quick anchor picker: choose an anchor point on the selected frame, then hover
-- another frame and choose its anchor point. The caller applies the result to its own position.
local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
-- Space between the two frames along each axis on which they would otherwise touch.
local GAP = 5
local MIN_MARKER, MAX_MARKER = 10, 22

local catcher, hint, sourceOverlay, targetOverlay
local state

local function Horizontal(point)
    return point:find("LEFT") and -1 or point:find("RIGHT") and 1 or 0
end

local function Vertical(point)
    return point:find("TOP") and 1 or point:find("BOTTOM") and -1 or 0
end

---Offset that keeps a frame anchored by `point` to `relativePoint` from overlapping its target:
---GAP pixels away on every axis where the two points face each other, zero elsewhere.
---@param point string
---@param relativePoint string
---@return number x, number y
function app.GetAnchorPickerOffset(point, relativePoint)
    local x, y = 0, 0
    local from, to = Horizontal(point), Horizontal(relativePoint)
    if from ~= 0 and from == -to then
        x = to * GAP
    end
    from, to = Vertical(point), Vertical(relativePoint)
    if from ~= 0 and from == -to then
        y = to * GAP
    end
    return x, y
end

local Stop

local function Choose(overlay, point)
    if not state then
        return
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if overlay == sourceOverlay then
        state.point = point
        state.targets = state.spec.targets() or {}
        sourceOverlay:Select(point)
        hint:SetText(L["Click an anchor point on another frame. Right-click or Escape cancels."])
        return
    end
    local spec, target, sourcePoint = state.spec, state.target, state.point
    Stop()
    if target and sourcePoint then
        local x, y = app.GetAnchorPickerOffset(sourcePoint, point)
        spec.apply(sourcePoint, target.value, point, x, y)
    end
end

local overlayMixin = {}

function overlayMixin:Attach(frame)
    self:ClearAllPoints()
    self:SetAllPoints(frame)
    local ratio = frame:GetEffectiveScale() / self:GetParent():GetEffectiveScale()
    local width, height = (frame:GetWidth() or 0) * ratio, (frame:GetHeight() or 0) * ratio
    local size = math.max(MIN_MARKER, math.min(MAX_MARKER, math.floor(math.min(width, height) / 3)))
    self.markerSize = size
    for _, marker in pairs(self.markers) do
        marker:SetSize(size, size)
        marker:UnlockHighlight()
        marker:Show()
    end
    self:Show()
end

-- Keep only the chosen point, highlighted, while the target is picked.
function overlayMixin:Select(point)
    for markerPoint, marker in pairs(self.markers) do
        marker:SetShown(markerPoint == point)
        marker:LockHighlight()
    end
end

-- The markers sit on the frame's edges, so half of each lies outside it.
function overlayMixin:IsMouseOverMarkers()
    local margin = (self.markerSize or 0) / 2
    return self:IsShown() and self:IsMouseOver(margin, -margin, -margin, margin)
end

local function CreateOverlay(level)
    local overlay = Mixin(CreateFrame("Frame", nil, catcher), overlayMixin)
    overlay:SetFrameLevel(level)
    overlay:Hide()
    local fill = overlay:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.3)
    overlay.markers = {}
    for _, point in ipairs(POINTS) do
        -- The same dark square button the game uses for small icon buttons.
        local marker = CreateFrame("Button", nil, overlay)
        marker:SetFrameLevel(level + 1)
        marker:SetPoint("CENTER", overlay, point)
        marker:SetNormalAtlas("common-dropdown-c-button")
        marker:SetPushedAtlas("common-dropdown-c-button-pressed-1")
        marker:SetHighlightAtlas("common-dropdown-c-button-hover-1", "ADD")
        marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        marker:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                Stop()
            else
                Choose(overlay, point)
            end
        end)
        overlay.markers[point] = marker
    end
    return overlay
end

-- The smallest listed frame under the cursor, so a frame inside another one stays reachable.
local function HoveredTarget()
    local best, bestArea
    for _, entry in ipairs(state.targets) do
        local frame = entry.frame
        if frame ~= state.spec.frame and frame:IsVisible() and frame:GetLeft() and frame:IsMouseOver() then
            local scale = frame:GetEffectiveScale()
            local area = frame:GetWidth() * frame:GetHeight() * scale * scale
            if not best or area < bestArea then
                best, bestArea = entry, area
            end
        end
    end
    return best
end

local function Update()
    local source = state.spec.frame
    if InCombatLockdown() or not EditModeManagerFrame:IsShown() or not source:IsVisible() then
        Stop()
        return
    end
    if not state.point then
        return
    end
    local current = state.target
    if current and (current.frame:IsMouseOver() or targetOverlay:IsMouseOverMarkers()) then
        return
    end
    local target = HoveredTarget()
    if target ~= current then
        state.target = target
        if target then
            targetOverlay:Attach(target.frame)
        else
            targetOverlay:Hide()
        end
    end
end

local function EnsureFrames()
    if catcher then
        return
    end
    -- Covers the screen above Edit Mode, so clicks while picking never select or drag a frame.
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:Hide()
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(100)
    catcher:RegisterForClicks("RightButtonUp")
    catcher:SetScript("OnClick", function()
        Stop()
    end)
    catcher:EnableKeyboard(true)
    catcher:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            return
        end
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            Stop()
        end
    end)
    catcher:SetScript("OnUpdate", Update)
    hint = catcher:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hint:SetPoint("TOP", 0, -120)
    sourceOverlay = CreateOverlay(110)
    targetOverlay = CreateOverlay(120)
end

function Stop()
    state = nil
    if catcher then
        sourceOverlay:Hide()
        targetOverlay:Hide()
        catcher:Hide()
    end
end

---Start picking. `spec.frame` is the selected frame, `spec.targets()` returns the frames it may
---anchor to as `{ frame, value }` entries, and `spec.apply(point, value, relativePoint, x, y)`
---receives the result.
---@param spec SeamlessCore.AnchorPicker
---@return boolean started
function app.StartAnchorPicker(spec)
    if InCombatLockdown() or not spec.frame or not spec.frame:IsVisible() then
        return false
    end
    EnsureFrames()
    Stop()
    state = { spec = spec }
    sourceOverlay:Attach(spec.frame)
    hint:SetText(L["Click an anchor point on the selected frame. Right-click or Escape cancels."])
    catcher:Show()
    return true
end

function app.StopAnchorPicker()
    Stop()
end

---@return boolean
function app.IsAnchorPickerActive()
    return state ~= nil
end

local addon = app.addon

---@param spec SeamlessCore.AnchorPicker
---@return boolean started
function addon:StartEditModeAnchorPicker(spec)
    return app.StartAnchorPicker(spec)
end

function addon:StopEditModeAnchorPicker()
    app.StopAnchorPicker()
end

---@return boolean
function addon:IsEditModeAnchorPickerActive()
    return app.IsAnchorPickerActive()
end
