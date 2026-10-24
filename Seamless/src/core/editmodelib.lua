---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance: our own settings window as its
-- dialog (also attached below Blizzard's settings dialog), Header and Button settings, and fixed
-- frames. The vendored files stay untouched; this
-- relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
local addon = app.addon
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(lib.SettingType.Button == nil, "LibEditMode now defines Button; review editmodelib.lua")
assert(type(internal.CreateDialog) == "function" and type(internal.MoveParent) == "function")
assert(type(internal.GetFrameSettings) == "function" and type(internal.GetFrameButtons) == "function")
assert(type(internal.TriggerCallback) == "function" and type(lib.frameSelections) == "table")

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

-- Setting kinds of our own. The settings window below draws them: a collapsible header (rows after
-- it, up to the next header, hide while it is collapsed) and a button whose `click(frame)` gets the
-- selected frame. Both support `name`, `hidden` and (buttons) `disabled`.
lib.SettingType.Header = "seamless-header"
lib.SettingType.Button = "seamless-button"

local function HeaderKey(data)
    return "settings:" .. (data.key or data.name)
end

local function Resolve(value)
    if type(value) == "function" then
        return value(lib:GetActiveLayoutName())
    end
    return value
end

local function Resolver(value)
    return function()
        return Resolve(value)
    end
end

-- The settings list scrolls past this height, like Blizzard's own settings container (325).
local MAX_HEIGHT, MAX_HEIGHT_SHARE = 400, 0.6
-- The window's width (the library dialog's 330 pixel rows plus its padding), the title's offset
-- and height, the gaps around the settings list, and the space below the buttons.
local WIDTH, TITLE_TOP, TITLE_HEIGHT, LIST_GAP, BOTTOM = 370, 15, 20, 12, 20
-- Width of the buttons in the window, as in the library's dialog.
local BUTTON_WIDTH = 200
-- Space between the window's right edge and its scroll bar, which sits outside the window.
local SCROLL_BAR_GAP = 2
-- Space between the selected frame and its settings window.
local DIALOG_GAP = 16
-- Gap to Blizzard's Edit Mode window when settings dialogs open beside it.
local MANAGER_GAP = 4
-- Arrow-key nudges, in pixels (with and without Shift), as in the library's dialog.
local BIG_STEP, SMALL_STEP = 10, 1
-- Space between the dialog the window attaches below and the window, and the frame levels the
-- window keeps above it.
local ATTACH_GAP, ATTACH_LEVELS = 8, 10
-- The window's own frame level, above the library's selection overlays.
local FRAME_LEVEL = 200
-- How often an attached window picks up changes made outside it (dragging, nudges, the other
-- dialog's own controls, Revert).
local POLL = 0.15

-- Set by a feature (SeamlessUI): open settings dialogs beside Blizzard's Edit Mode window instead
-- of beside their frame.
local besideManager = false

-- Places a settings dialog right of Blizzard's Edit Mode window, aligned with its top and kept on
-- screen, in absolute coordinates like a drop after dragging, so it never follows the window.
-- Returns whether it was placed. Only re-anchors: Blizzard's dialog is an unprotected frame that
-- nothing reads the position of.
local function PlaceBesideManager(dialog)
    local manager = EditModeManagerFrame
    if not manager or not manager:IsShown() then
        return false
    end
    local right, top = manager:GetRight(), manager:GetTop()
    local width, height = dialog:GetWidth(), dialog:GetHeight()
    if not right or not top or not width or not height then
        return false
    end
    local scale = dialog:GetEffectiveScale()
    local ratio = manager:GetEffectiveScale() / scale
    local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale
    local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale() / scale
    local x = math.max(math.min(right * ratio + MANAGER_GAP, screenWidth - width), 0)
    local y = math.max(math.min(top * ratio, screenHeight), math.min(height, screenHeight))
    dialog:ClearAllPoints()
    dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    return true
end

-- Open beside the selected frame, on the side with more room, aligned with its top edge.
-- Coordinates are converted to the dialog's scale; it does not follow the frame afterwards.
local function PlaceBesideFrame(dialog, frame)
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

-- The library dialog's own Reset Position rules, for a frame without a stored default.
local CENTER = { point = "CENTER", x = 0, y = 0 }

local function DefaultPosition(frame)
    return lib:GetFrameDefaultPosition(frame) or CopyTable(CENTER)
end

local function IsDefaultPosition(frame)
    local point, _, _, x, y = frame:GetPoint()
    local default = DefaultPosition(frame)
    return point == default.point and math.abs(x - default.x) < 0.01 and math.abs(y - default.y) < 0.01
end

local function ResetPosition(frame)
    if InCombatLockdown() then
        return
    end
    local position = DefaultPosition(frame)
    frame:ClearAllPoints()
    frame:SetPoint(position.point, position.x, position.y)
    internal:TriggerCallback(frame, position.point, position.x, position.y)
end

-- Rows already made for a setting: the renderer only initializes a row again (ending a slider
-- drag) when it is handed a different option table.
local convertedRows = setmetatable({}, { __mode = "k" })

-- One renderer row for one library setting of the selected frame.
local function ConvertSetting(data, index, frame)
    local cached = convertedRows[data]
    if cached and cached.index == index and cached.frame == frame then
        return cached.row
    end
    local kind = data.kind
    local row = {
        key = kind .. ":" .. index,
        name = data.name,
        desc = data.desc,
        hidden = Resolver(data.hidden),
        disabled = Resolver(data.disabled),
    }
    local function get()
        local value = data.get(lib:GetActiveLayoutName())
        if value == nil then
            value = data.default
        end
        return value
    end
    local function set(value)
        data.set(lib:GetActiveLayoutName(), value, false)
    end
    if kind == lib.SettingType.Checkbox then
        row.type, row.get, row.set = "toggle", get, set
    elseif kind == lib.SettingType.Dropdown then
        row.type, row.get, row.set = "select", get, set
        row.values, row.scroll = data.values, data.height
    elseif kind == lib.SettingType.Slider then
        row.type, row.get, row.set = "range", get, set
        row.min, row.max, row.step = data.minValue or 0, data.maxValue or 1, data.valueStep or 1
        row.format = data.formatter
    elseif kind == lib.SettingType.Button then
        row.type, row.width = "button", BUTTON_WIDTH
        row.click = function()
            if data.click and not InCombatLockdown() then
                data.click(frame)
            end
        end
    else
        error("Suite frames support Checkbox, Dropdown, Slider, Header and Button settings, not " .. tostring(kind))
    end
    convertedRows[data] = { index = index, frame = frame, row = row }
    return row
end

---@class SeamlessCore.EditModeAttachedSettings
---@field anchor table The dialog the window attaches below; the window takes its width.
---@field title string
---@field key any What is shown (a Blizzard system); the list scrolls back to the top when it changes.
---@field sections fun(): SeamlessCore.EditModeSection[] Built again on every layout.
---@field changed? fun() Called after a row changed a value (default: lay the window out again).

---@class SeamlessCore.EditModeSettingsWindow : Frame
---@field selection table? LibEditMode's selection of the frame whose settings are shown.
---@field attached SeamlessCore.EditModeAttachedSettings? Set while attached below another dialog.

-- The settings window of suite frames. LibEditMode shows it as its dialog: the library keeps
-- selecting, dragging and calling Update/Reset/Hide, and the window draws the selected frame's
-- settings with the shared row renderer (editmoderows.lua) instead of the library's widgets.
-- For a Blizzard frame, a feature attaches the same window below Blizzard's settings dialog with
-- its own sections (AttachEditModeSettingsWindow); it then has no close button, buttons or
-- dragging, and follows that dialog.
local function CreateSettingsWindow()
    local window = CreateFrame("Frame", "SeamlessEditModeSettingsDialog", UIParent) --[[@as SeamlessCore.EditModeSettingsWindow]]
    window:SetSize(WIDTH, 350)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(FRAME_LEVEL)
    window:Hide()
    -- Draggable like the library's dialog; arrow keys nudge the selected frame.
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetDontSavePosition(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        if not self.attached then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)

    local border = CreateFrame("Frame", nil, window, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    window.Title = window:CreateFontString(nil, nil, "GameFontHighlightLarge")
    window.Title:SetPoint("TOP", 0, -TITLE_TOP)
    window.Title:SetHeight(TITLE_HEIGHT)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    close:HookScript("OnClick", function()
        window:Reset()
    end)
    window.Close = close

    -- The settings list scrolls; the buttons below it always stay in view.
    local scroll = CreateFrame("ScrollFrame", nil, window, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -(TITLE_TOP + TITLE_HEIGHT + LIST_GAP))
    scroll:SetWidth(WIDTH)
    scroll:EnableMouseWheel(true)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    -- Outside the window's right edge, so it never takes width from the rows.
    scroll.ScrollBar:ClearAllPoints()
    scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", SCROLL_BAR_GAP, 0)
    scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", SCROLL_BAR_GAP, 0)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(WIDTH, 1)
    scroll:SetScrollChild(list)
    local buttons = CreateFrame("Frame", nil, window)
    buttons:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -LIST_GAP)
    buttons:SetSize(WIDTH, 1)
    window.Scroll, window.List, window.Buttons = scroll, list, buttons

    local function Redraw()
        if window.selection or window.attached then
            window:LayoutContent()
        end
    end

    -- Back from the attached placement to the library dialog's own look.
    local function Detach()
        window.attached = nil
        window.Close:Show()
        window:SetFrameLevel(FRAME_LEVEL)
        window:ClearAllPoints()
        window:SetWidth(WIDTH)
    end

    local function ResetSettings()
        local settings = internal:GetFrameSettings(window.selection.parent)
        for _, data in ipairs(settings or {}) do
            if data.set then
                data.set(lib:GetActiveLayoutName(), data.default, true)
            end
        end
    end

    -- The selected frame's settings, one section per header, then Reset To Default.
    local function ListSections(frame)
        local settings, count = internal:GetFrameSettings(frame)
        local sections = { { id = "settings", options = {} } }
        for index, data in ipairs(settings or {}) do
            if data.kind == lib.SettingType.Header then
                sections[#sections + 1] = {
                    id = "header:" .. index,
                    name = data.name,
                    key = HeaderKey(data),
                    hidden = Resolver(data.hidden),
                    options = {},
                }
            else
                table.insert(sections[#sections].options, ConvertSetting(data, index, frame))
            end
        end
        sections[#sections + 1] = {
            id = "reset",
            options = {
                {
                    key = "reset",
                    type = "button",
                    name = RESET_TO_DEFAULT,
                    width = BUTTON_WIDTH,
                    disabled = count == 0,
                    click = ResetSettings,
                },
                { key = "divider", type = "divider" },
            },
        }
        return sections
    end

    -- The frame's own buttons, then Reset Position (left out for frames that never move).
    local function ButtonSections(frame)
        local options = {}
        for index, data in ipairs((internal:GetFrameButtons(frame)) or {}) do
            options[#options + 1] = {
                key = "button:" .. index,
                type = "button",
                name = data.text,
                width = BUTTON_WIDTH,
                click = data.click,
            }
        end
        options[#options + 1] = {
            key = "resetPosition",
            type = "button",
            name = HUD_EDIT_MODE_RESET_POSITION,
            width = BUTTON_WIDTH,
            hidden = fixedFrames[frame] == true,
            disabled = IsDefaultPosition(frame),
            click = function()
                ResetPosition(frame)
            end,
        }
        return { { id = "buttons", options = options } }
    end

    ---Draw the selected frame's settings (or the attached sections) and size the window to them,
    ---growing downward only.
    function window:LayoutContent()
        local attached, frame = self.attached, self.selection and self.selection.parent
        if not attached then
            -- Pin the top edge where it is now, so resizing only moves the bottom edge.
            local left, top = self:GetLeft(), self:GetTop()
            if left and top then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            end
        end
        -- Attached, the window takes the width of the dialog above it.
        local width = self:GetWidth()
        if not width or width <= 0 then
            width = WIDTH
        end
        scroll:SetWidth(width)
        list:SetWidth(width)
        buttons:SetWidth(width)
        local sections = attached and attached.sections() or ListSections(frame)
        local changed = attached and attached.changed or Redraw
        local listHeight = addon:LayoutEditModeSections(list, sections, 0, false, changed)
        list:SetHeight(math.max(1, listHeight))
        local maximum = math.floor(math.min(MAX_HEIGHT, UIParent:GetHeight() * MAX_HEIGHT_SHARE))
        local scrollHeight = math.min(listHeight, maximum)
        scroll:SetHeight(math.max(1, scrollHeight))
        local buttonsHeight = 0
        if not attached then
            buttonsHeight = addon:LayoutEditModeSections(buttons, ButtonSections(frame), 0, false, Redraw)
        end
        -- An empty button list is left out of the window.
        buttons:SetShown(buttonsHeight > 0)
        buttons:SetHeight(math.max(1, buttonsHeight))
        local height = TITLE_TOP + TITLE_HEIGHT + LIST_GAP + scrollHeight + BOTTOM
        if buttonsHeight > 0 then
            height = height + LIST_GAP + buttonsHeight
        end
        self:SetHeight(height)
        scroll:UpdateScrollChildRect()
        local range = scroll:GetVerticalScrollRange()
        if scroll:GetVerticalScroll() > range then
            scroll:SetVerticalScroll(range)
        end
    end

    -- Called by the library on selection and whenever a feature refreshes the frame's settings.
    function window:Update(selection)
        if self.attached then
            Detach()
        end
        local newSelection = selection ~= self.selection
        self.selection = selection
        self.Title:SetText(selection.system:GetSystemName())
        if newSelection then
            scroll:SetVerticalScroll(0)
        end
        self:Show()
        self:LayoutContent()
        if newSelection and selection.parent and not (besideManager and PlaceBesideManager(self)) then
            PlaceBesideFrame(self, selection.parent)
        end
    end

    function window:RefreshWidgets()
        Redraw()
    end

    -- Called by the library before showing another frame's settings and when a Blizzard frame is
    -- selected; never hide here, the library's OnHide hook clears the selection.
    function window:Reset()
        if self.attached then
            Detach()
        end
        self.selection = nil
        self:ClearAllPoints()
        self:SetPoint("BOTTOMRIGHT", UIParent, -250, 250)
    end

    ---Show `spec.sections` below `spec.anchor` instead of a suite frame's settings.
    ---@param spec SeamlessCore.EditModeAttachedSettings
    function window:Attach(spec)
        local new = not self.attached or self.attached.key ~= spec.key
        self.selection = nil
        self.attached = spec
        self.Title:SetText(spec.title)
        self.Close:Hide()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", spec.anchor, "BOTTOMLEFT", 0, -ATTACH_GAP)
        self:SetPoint("TOPRIGHT", spec.anchor, "BOTTOMRIGHT", 0, -ATTACH_GAP)
        self:SetFrameLevel(spec.anchor:GetFrameLevel() + ATTACH_LEVELS)
        if new then
            scroll:SetVerticalScroll(0)
        end
        self:Show()
        self:LayoutContent()
    end

    ---Hide the window if it is attached; a suite frame's settings stay as they are.
    function window:Detach()
        if self.attached then
            Detach()
            self:Hide()
            self:Reset()
        end
    end

    -- Attached, poll while shown and refresh the rows in place: laying the window out again each
    -- time would interrupt clicks, so that only happens when rows appear, disappear or change
    -- height. Suite frames refresh through the library instead.
    local elapsed = 0
    window:SetScript("OnUpdate", function(self, delta)
        if not self.attached then
            return
        end
        elapsed = elapsed + delta
        if elapsed >= POLL then
            elapsed = 0
            if addon:RefreshEditModeSections(list) then
                self:LayoutContent()
            end
        end
    end)

    window:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            return
        end
        local selection = self.selection
        if not selection then
            self:SetPropagateKeyboardInput(true)
            return
        end
        self:SetPropagateKeyboardInput(false)
        local step = IsShiftKeyDown() and BIG_STEP or SMALL_STEP
        if key == "LEFT" then
            internal:MoveParent(selection, -step)
        elseif key == "RIGHT" then
            internal:MoveParent(selection, step)
        elseif key == "UP" then
            internal:MoveParent(selection, 0, step)
        elseif key == "DOWN" then
            internal:MoveParent(selection, 0, -step)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    window:Reset()
    return window
end

local settingsWindow
local function GetSettingsWindow()
    settingsWindow = settingsWindow or CreateSettingsWindow()
    return settingsWindow
end

-- The one replacement in the library: its dialog is our window. Nothing else in it changes.
assert(not internal.dialog, "LibEditMode created its dialog before Core could replace it")
function internal:CreateDialog()
    return GetSettingsWindow()
end

-- Public API for feature addons: the same header, collapse state and Position section in every window.
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

---Open the settings dialog of a newly selected frame beside Blizzard's Edit Mode window instead
---of beside the frame. Off by default; the player can still drag the dialog.
---@param enabled boolean
function addon:SetEditModeDialogsBesideManager(enabled)
    besideManager = enabled and true or false
end

---Moves a settings dialog (also Blizzard's `EditModeSystemSettingsDialog`) right of Blizzard's
---Edit Mode window, top-aligned and on screen. Only re-anchors it; returns whether it was placed.
---@param dialog table
---@return boolean placed
function addon:PlaceBesideEditModeManager(dialog)
    return PlaceBesideManager(dialog)
end

---Show the settings window below another dialog (Blizzard's `EditModeSystemSettingsDialog`) with
---the given sections, until DetachEditModeSettingsWindow or a suite frame is selected. Call it
---again to refresh. While shown it polls `RefreshEditModeSections` for changes made elsewhere.
---@param spec SeamlessCore.EditModeAttachedSettings
function addon:AttachEditModeSettingsWindow(spec)
    GetSettingsWindow():Attach(spec)
end

---Hide the settings window if it is attached; it is left alone while it shows a suite frame.
function addon:DetachEditModeSettingsWindow()
    if settingsWindow then
        settingsWindow:Detach()
    end
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
