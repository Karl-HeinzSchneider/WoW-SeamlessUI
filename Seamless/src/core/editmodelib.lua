---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance. The vendored files stay
-- untouched; this relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(lib.SettingType.Button == nil, "LibEditMode now defines Button; review editmodelib.lua")
assert(type(internal.CreatePool) == "function" and type(internal.CreateDialog) == "function")
assert(type(internal.MoveParent) == "function" and type(lib.frameSelections) == "table")

-- Frames that can be selected in Edit Mode but never moved: no dragging, no arrow-key nudges and
-- no Reset Position button.
local fixedFrames = {}
local moveParent = internal.MoveParent
function internal:MoveParent(selection, ...)
    if not fixedFrames[selection.parent] then
        return moveParent(self, selection, ...)
    end
end

-- Collapsed sections are remembered account-wide, by section key.
local collapsedFallback = {}
local function CollapsedSections()
    if not app.db then
        return collapsedFallback
    end
    app.db.global.editModeCollapsed = app.db.global.editModeCollapsed or {}
    return app.db.global.editModeCollapsed
end

-- Every Position header shares this key, so it collapses in all windows at once.
local POSITION_SECTION = "settings:position"
-- The Frames list in the main Edit Mode window (editmode.lua).
local FRAMES_SECTION = "panel:frames"
-- Sections that start collapsed until the user opens them; opening one is saved as false.
local COLLAPSED_BY_DEFAULT = { [POSITION_SECTION] = true, [FRAMES_SECTION] = true }

---@param key string
---@return boolean
function app.IsEditModeSectionCollapsed(key)
    local collapsed = CollapsedSections()[key]
    if collapsed == nil then
        return COLLAPSED_BY_DEFAULT[key] == true
    end
    return collapsed
end

---@param key string
---@param collapsed boolean
function app.SetEditModeSectionCollapsed(key, collapsed)
    collapsed = not not collapsed
    if collapsed == (COLLAPSED_BY_DEFAULT[key] == true) then
        CollapsedSections()[key] = nil
    else
        CollapsedSections()[key] = collapsed
    end
end

local function SetCollapsedState(header, collapsed)
    header.StateIcon:SetAtlas(collapsed and "common-button-list-plus" or "common-button-list-minus", true)
end

local function SetHeaderText(header, text)
    header.Name:SetText(text)
end

---Create a collapsible section header that looks like the character frame's reputation headers:
---the collapse/expand bar, a gold name on the left and a +/- icon on the right.
---@param parent table
---@param onClick fun()
---@return table header
function app.CreateEditModeHeader(parent, onClick)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(28)
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-button-list-collapseExpand")
    background:SetAllPoints()
    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("common-button-list-collapseExpand")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)
    highlight:SetAllPoints()
    header.StateIcon = header:CreateTexture(nil, "BORDER")
    header.StateIcon:SetPoint("RIGHT", -8, -1)
    header.Name = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
    header.Name:SetPoint("LEFT", 10, 0)
    header.Name:SetPoint("RIGHT", header.StateIcon, "LEFT", -4, 0)
    header.SetHeaderText = SetHeaderText
    header.UpdateCollapsedState = SetCollapsedState
    -- Nudge the name while pressed. A header hidden mid-press never gets OnMouseUp, so OnHide
    -- releases it too; otherwise the name drifts a pixel per lost press.
    local function release()
        if header.pressed then
            header.pressed = nil
            header.Name:AdjustPointsOffset(-1, 1)
        end
    end
    header:SetScript("OnMouseDown", function()
        if not header.pressed then
            header.pressed = true
            header.Name:AdjustPointsOffset(1, -1)
        end
    end)
    header:SetScript("OnMouseUp", release)
    header:SetScript("OnHide", release)
    header:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    SetCollapsedState(header, false)
    return header
end

-- Collapsible section header. Rows after it, up to the next header, hide while it is collapsed.
lib.SettingType.Header = "seamless-header"

local function HeaderKey(data)
    return "settings:" .. (data.key or data.name)
end

local headerMixin = {}
function headerMixin:Setup(data)
    self.setting = data
    self:SetHeaderText(data.name)
    self:Refresh()
end

function headerMixin:Refresh()
    local data = self.setting
    if type(data.hidden) == "function" then
        self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
    else
        self:SetShown(not data.hidden)
    end
    self:UpdateCollapsedState(self:IsCollapsed())
end

function headerMixin:IsCollapsed()
    return app.IsEditModeSectionCollapsed(HeaderKey(self.setting))
end

function headerMixin:Toggle()
    app.SetEditModeSectionCollapsed(HeaderKey(self.setting), not self:IsCollapsed())
    self:GetParent():GetParent():RefreshWidgets()
end

internal:CreatePool(lib.SettingType.Header, function()
    local frame
    frame = app.CreateEditModeHeader(UIParent, function()
        frame:Toggle()
    end)
    Mixin(frame, headerMixin)
    frame:SetWidth(330)
    return frame
end, function(_, frame)
    frame:Hide()
    frame:SetHeaderText("")
    frame.layoutIndex = nil
end)

-- A full-width button row inside the settings list (the library's own buttons sit below it).
-- `click(frame)` receives the selected frame; supports `name`, `hidden` and `disabled`.
lib.SettingType.Button = "seamless-button"

local function Resolve(value)
    if type(value) == "function" then
        return value(lib:GetActiveLayoutName())
    end
    return value
end

local buttonMixin = {}
function buttonMixin:Setup(data)
    self.setting = data
    self.Button:SetText(data.name)
    self:Refresh()
end

function buttonMixin:Refresh()
    self:SetShown(not Resolve(self.setting.hidden))
    self.Button:SetEnabled(not Resolve(self.setting.disabled))
end

internal:CreatePool(lib.SettingType.Button, function()
    local frame = Mixin(CreateFrame("Frame", nil, UIParent), buttonMixin)
    frame:SetSize(330, 32)
    frame.Button = CreateFrame("Button", nil, frame, "EditModeSystemSettingsDialogButtonTemplate")
    frame.Button:SetPoint("CENTER")
    frame.Button:SetWidth(200)
    frame.Button:SetOnClickHandler(function()
        local selection = internal.dialog and internal.dialog.selection
        if selection and frame.setting and frame.setting.click and not InCombatLockdown() then
            frame.setting.click(selection.parent)
        end
    end)
    return frame
end, function(_, frame)
    frame:Hide()
    frame.setting = nil
    frame.layoutIndex = nil
end)

-- The settings list scrolls past this height, like Blizzard's own settings container (325).
local MAX_HEIGHT, MAX_HEIGHT_SHARE = 400, 0.6

-- Hide every row after a collapsed header, up to the next header.
local function ApplyCollapsed(dialog)
    local collapsed = false
    for _, widget in ipairs(dialog.Settings.widgets) do
        if widget.setting and widget.setting.kind == lib.SettingType.Header then
            collapsed = widget:IsShown() and widget:IsCollapsed()
        elseif collapsed then
            widget:Hide()
        end
    end
end

-- Space between the window's right edge and its scroll bar, which sits outside the window.
local SCROLL_BAR_GAP = 2
-- Space between the selected frame and its settings window.
local DIALOG_GAP = 16

-- Put the selected frame's settings list in a scroll frame, built like Blizzard's own
-- Edit Mode settings container (ResizeLayoutFrame + ScrollFrameTemplate with a maximum height).
local function AddScrolling(dialog)
    local settings = dialog.Settings
    local scroll = CreateFrame("ScrollFrame", nil, dialog, "ResizeLayoutFrame, ScrollFrameTemplate")
    scroll:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -12)
    -- LayoutFrame only applies maximumHeight when a minimum is set as well.
    scroll.minimumHeight = 1
    scroll:EnableMouseWheel(true)
    scroll.ScrollBar.ignoreInLayout = true
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    -- Widgets refresh through their grandparent, which is the scroll frame now.
    function scroll:RefreshWidgets()
        dialog:RefreshWidgets()
    end
    settings:ClearAllPoints()
    settings:SetParent(scroll)
    scroll:SetScrollChild(settings)
    dialog.Buttons:ClearAllPoints()
    dialog.Buttons:SetPoint("TOP", scroll, "BOTTOM", 0, -12)
    dialog.SettingsScroll = scroll

    -- Keep the scroll bar outside the window's right edge, so it never takes width from the rows.
    local function PlaceScrollBar()
        local dialogRight, scrollRight = dialog:GetRight(), scroll:GetRight()
        local inset = (dialogRight and scrollRight) and (dialogRight - scrollRight) or dialog.widthPadding / 2
        local bar = scroll.ScrollBar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", inset + SCROLL_BAR_GAP, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", inset + SCROLL_BAR_GAP, 0)
    end

    -- Size the scroll frame from the list itself, so collapsing a section always shrinks the window.
    local function LayoutDialog()
        -- Pin the top edge where it is now, so resizing only moves the bottom edge.
        local left, top = dialog:GetLeft(), dialog:GetTop()
        if left and top then
            dialog:ClearAllPoints()
            dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        settings:Layout()
        scroll.fixedWidth = settings:GetWidth()
        scroll.fixedHeight = math.min(settings:GetHeight(), scroll.maximumHeight)
        -- Resize the scroll frame first: the dialog measures the buttons below it before
        -- reaching the scroll frame itself, which it created last.
        scroll:Layout()
        dialog:Layout()
        scroll:UpdateScrollChildRect()
        local range = scroll:GetVerticalScrollRange()
        if scroll:GetVerticalScroll() > range then
            scroll:SetVerticalScroll(range)
        end
        PlaceScrollBar()
    end

    -- Open beside the selected frame, on the side with more room, aligned with its top edge.
    -- Coordinates are converted to the dialog's scale; it does not follow the frame afterwards.
    local function PlaceBesideFrame(frame)
        local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
        local width, height = dialog:GetWidth(), dialog:GetHeight()
        if not left or not right or not top or not width or not height then
            return
        end
        local scale = dialog:GetEffectiveScale()
        local ratio = frame:GetEffectiveScale() / scale
        left, right, top = left * ratio, right * ratio, top * ratio
        local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale
        local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale() / scale
        local x
        if screenWidth - right >= left then
            x = math.min(right + DIALOG_GAP, screenWidth - width)
        else
            x = math.max(left - DIALOG_GAP - width, 0)
        end
        local y = math.max(math.min(top, screenHeight), math.min(height, screenHeight))
        dialog:ClearAllPoints()
        dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end

    -- Features refresh the dialog from their setters (RefreshFrameSettings), and LibEditMode's
    -- Update releases and rebuilds every widget, which ends a slider drag after one step. While a
    -- slider is held, an Update of the same selection only refreshes the rows in place; one full
    -- Update follows on the first frame after the mouse button is released, outside any slider
    -- script (rebuilding inside the slider's own OnMouseUp left the next grab stuck).
    local heldSlider, pendingUpdate
    local hookedSliders = {}
    local releaseWatcher = CreateFrame("Frame")
    local function StopHolding()
        heldSlider, pendingUpdate = nil, nil
        releaseWatcher:SetScript("OnUpdate", nil)
    end
    local function WatchRelease()
        if IsMouseButtonDown("LeftButton") then
            return
        end
        local pending = pendingUpdate
        StopHolding()
        if pending and dialog:IsShown() and dialog.selection then
            dialog:Update(dialog.selection)
        end
    end
    local function Hold(slider)
        heldSlider = slider
        releaseWatcher:SetScript("OnUpdate", WatchRelease)
    end
    local function OnSliderMouseDown(slider, button)
        if button == "LeftButton" then
            Hold(slider)
        end
    end
    -- A click on the track can change the value before the slider's OnMouseDown script runs.
    local function PressedSlider()
        if not IsMouseButtonDown("LeftButton") then
            return nil
        end
        for _, widget in ipairs(settings.widgets) do
            local slider = widget.Slider and widget.Slider.Slider
            if slider and slider:IsVisible() and slider:IsMouseOver() then
                return slider
            end
        end
        return nil
    end
    local function HookSliders()
        for _, widget in ipairs(settings.widgets) do
            local slider = widget.Slider and widget.Slider.Slider
            if slider and not hookedSliders[slider] then
                hookedSliders[slider] = true
                slider:HookScript("OnMouseDown", OnSliderMouseDown)
            end
        end
    end
    dialog:HookScript("OnHide", StopHolding)

    local update, refreshWidgets = dialog.Update, dialog.RefreshWidgets
    function dialog:Update(selection)
        local newSelection = selection ~= self.selection
        local held = not newSelection and self:IsShown() and (heldSlider or PressedSlider())
        if held then
            Hold(held)
            pendingUpdate = true
            self:RefreshWidgets()
            return
        end
        StopHolding()
        if newSelection then
            scroll:SetVerticalScroll(0)
        end
        scroll.maximumHeight = math.floor(math.min(MAX_HEIGHT, UIParent:GetHeight() * MAX_HEIGHT_SHARE))
        -- Measure with every section open, then keep that width so collapsing never resizes the window.
        settings.fixedWidth = nil
        self.Buttons:Show()
        update(self, selection)
        settings.fixedWidth = settings:GetWidth()
        if selection.parent and fixedFrames[selection.parent] and self.Buttons.ResetPositionButton then
            self.Buttons.ResetPositionButton:Hide()
            -- An empty button list has no valid size and stretched the window across the screen;
            -- hidden, the window leaves it out.
            local anyShown = false
            for _, button in ipairs({ self.Buttons:GetChildren() }) do
                anyShown = anyShown or button:IsShown()
            end
            if anyShown then
                self.Buttons:Layout()
            else
                self.Buttons:Hide()
            end
        end
        HookSliders()
        ApplyCollapsed(self)
        LayoutDialog()
        if newSelection and selection.parent then
            PlaceBesideFrame(selection.parent)
        end
    end
    -- Never hide the dialog here: its OnHide clears the frame selection.
    function dialog:RefreshWidgets()
        refreshWidgets(self)
        ApplyCollapsed(self)
        if self:IsShown() then
            LayoutDialog()
        end
    end
end

if internal.dialog then
    AddScrolling(internal.dialog)
else
    local createDialog = internal.CreateDialog
    function internal:CreateDialog()
        local dialog = createDialog(self)
        AddScrolling(dialog)
        return dialog
    end
end

-- Public API for feature addons: the same header, collapse state and Position section in every window.
local addon = app.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@param parent table
---@param onClick fun()
---@return table header
function addon:CreateEditModeHeader(parent, onClick)
    return app.CreateEditModeHeader(parent, onClick)
end

---@param key string
---@return boolean
function addon:IsEditModeSectionCollapsed(key)
    return app.IsEditModeSectionCollapsed(key)
end

---@param key string
---@param collapsed boolean
function addon:SetEditModeSectionCollapsed(key, collapsed)
    app.SetEditModeSectionCollapsed(key, collapsed)
end

---@return string
---Keep a frame registered with LibEditMode's AddFrame selectable, with its settings, but never
---movable: for a preview of a frame the client places itself.
---@param frame table
function addon:SetEditModeFrameFixed(frame)
    local selection = lib.frameSelections[frame]
    assert(selection, "Register the frame with AddFrame first")
    fixedFrames[frame] = true
    selection:SetScript("OnDragStart", nil)
    selection:SetScript("OnDragStop", nil)
end

function addon:GetEditModePositionSectionKey()
    return POSITION_SECTION
end

local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POINT_LABELS = {
    TOPLEFT = L["Top left"],
    TOP = L["Top"],
    TOPRIGHT = L["Top right"],
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"],
    BOTTOMLEFT = L["Bottom left"],
    BOTTOM = L["Bottom"],
    BOTTOMRIGHT = L["Bottom right"],
}

---LibEditMode settings for a collapsible Position section: Scale, Anchor, AnchorParent, AnchorFrame,
---X, Y and an "Quick anchor to frame" button that starts the anchor picker. Scale uses the same
---`spec.scale` binding as the settings panel's Position and scale group, and is shown disabled
---without one.
---`spec.get(key)` and `spec.set(key, value)` use the keys point, relativePoint, relativeTo, x and y;
---`spec.anchorFrames()` returns `{ text, value }` entries for relativeTo, and the optional
---`spec.anchorFrame(value)` returns the frame of an entry (default: the global of that name).
---@param spec SeamlessCore.EditModePosition
---@return table[] settings
function addon:GetEditModePositionSettings(spec)
    local function disabled()
        return spec.disabled ~= nil and spec.disabled() or false
    end
    local function setter(key)
        return function(_, value, fromReset)
            -- Reset To Default leaves the position alone; Reset Position restores it.
            if not fromReset and not disabled() and not InCombatLockdown() then
                spec.set(key, value)
            end
        end
    end
    local function getter(key)
        return function()
            return spec.get(key)
        end
    end
    local points = {}
    for _, point in ipairs(POINTS) do
        points[#points + 1] = { text = POINT_LABELS[point], value = point }
    end
    local function offset(name, key, extent)
        extent = math.max(1, math.ceil(extent))
        return {
            name = name,
            kind = lib.SettingType.Slider,
            default = 0,
            minValue = -extent,
            maxValue = extent,
            valueStep = 1,
            get = function()
                return spec.get(key) or 0
            end,
            set = setter(key),
            disabled = disabled,
            formatter = function(value)
                return tostring(math.floor(value + 0.5))
            end,
        }
    end
    local function dropdown(name, key, values, height)
        return {
            name = name,
            kind = lib.SettingType.Dropdown,
            get = getter(key),
            set = setter(key),
            disabled = disabled,
            values = values,
            height = height,
        }
    end
    local scale = spec.scale or {}
    local function scaleDisabled()
        return not scale.get or not scale.set or disabled() or (scale.disabled ~= nil and scale.disabled()) or false
    end
    local scaleRow = {
        name = L["Scale"],
        kind = lib.SettingType.Slider,
        default = (type(scale.default) == "function" and scale.default() or scale.default) or 1,
        minValue = scale.min or 0.5,
        maxValue = scale.max or 2,
        valueStep = scale.step or 0.01,
        get = scale.get or function()
            return 1
        end,
        set = function(_, value, fromReset)
            -- Reset To Default leaves the scale alone, like the position rows.
            if not fromReset and not scaleDisabled() and not InCombatLockdown() then
                scale.set(value)
            end
        end,
        disabled = scaleDisabled,
        -- The settings panel's units: 1 is 100 %.
        formatter = function(value)
            return string.format("%.12g", math.floor(value * 100 + 0.5) / 100)
        end,
    }
    return {
        { name = L["Position"], key = "position", kind = lib.SettingType.Header },
        scaleRow,
        dropdown(L["Anchor"], "point", points),
        dropdown(L["AnchorParent"], "relativePoint", points),
        dropdown(L["AnchorFrame"], "relativeTo", spec.anchorFrames, 400),
        offset(L["X"], "x", UIParent:GetWidth()),
        offset(L["Y"], "y", UIParent:GetHeight()),
        {
            name = L["Quick anchor to frame"],
            kind = lib.SettingType.Button,
            disabled = disabled,
            click = function(frame)
                app.StartAnchorPicker({
                    frame = frame,
                    targets = function()
                        local values = type(spec.anchorFrames) == "function" and spec.anchorFrames()
                            or spec.anchorFrames
                        local targets = {}
                        for _, entry in ipairs(values or {}) do
                            local target
                            if spec.anchorFrame then
                                target = spec.anchorFrame(entry.value)
                            elseif type(entry.value) == "string" then
                                target = _G[entry.value]
                            end
                            if type(target) == "table" and target ~= UIParent and target.IsObjectType then
                                targets[#targets + 1] = { frame = target, value = entry.value }
                            end
                        end
                        return targets
                    end,
                    apply = function(point, value, relativePoint, x, y)
                        if disabled() or InCombatLockdown() or not lib:IsInEditMode() then
                            return
                        end
                        spec.set("relativeTo", value)
                        spec.set("point", point)
                        spec.set("relativePoint", relativePoint)
                        spec.set("x", x)
                        spec.set("y", y)
                        lib:RefreshFrameSettings(frame)
                    end,
                })
            end,
        },
    }
end
