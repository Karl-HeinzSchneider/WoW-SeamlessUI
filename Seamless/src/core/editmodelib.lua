---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance: our own settings window as its
-- dialog (also attached below Blizzard's settings dialog), Header and Button settings, and fixed
-- frames. The vendored files stay untouched; this
-- relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
local addon = app.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(lib.SettingType.Button == nil, "LibEditMode now defines Button; review editmodelib.lua")
assert(lib.SettingType.Position == nil, "LibEditMode now defines Position; review editmodelib.lua")
assert(lib.SettingType.ButtonSection == nil, "LibEditMode now defines ButtonSection; review editmodelib.lua")
assert(lib.SettingType.Option == nil, "LibEditMode now defines Option; review editmodelib.lua")
assert(type(internal.CreateDialog) == "function" and type(internal.MoveParent) == "function")
assert(type(internal.GetFrameSettings) == "function")
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
-- it, up to the next header, hide while it is collapsed), a button whose `click(frame)` gets the
-- selected frame (both support `name`, `hidden` and, buttons, `disabled`) and the shared Position
-- section (GetEditModePositionSetting).
lib.SettingType.Header = "seamless-header"
lib.SettingType.Button = "seamless-button"
lib.SettingType.Position = "seamless-position"
lib.SettingType.ButtonSection = "seamless-button-section"
-- A settings page control (editmodepages.lua): `row` is a renderer row bound to the page option.
lib.SettingType.Option = "seamless-option"

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
    if kind == lib.SettingType.Option then
        return data.row
    end
    local row = {
        key = kind .. ":" .. index,
        name = data.name,
        desc = data.desc,
        default = data.default,
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

-- Position spec keys and the section's value keys they map to, in the order changes are written:
-- the anchor frame first, as the anchor picker does.
local POSITION_FIELDS = {
    { "relativeTo", "relativeTo" },
    { "point", "point" },
    { "relativePoint", "relativePoint" },
    { "x", "offsetX" },
    { "y", "offsetY" },
}

local function Finite(value)
    return value ~= nil and value == value and value > -math.huge and value < math.huge
end

-- The Position section of the selected frame, kept while it stays selected: it holds the values
-- Revert restores and the last refusal, retained across selections in this session.
local positionSections = {}

-- Snapshot values, rather than clicks: returning a control to its original value
-- must clear Revert again. Keep baselines when selecting another frame.
local settingSnapshots = {}
local snapshotProfile
local function ClearSnapshots()
    table.wipe(settingSnapshots)
    table.wipe(positionSections)
end
lib:RegisterCallback("enter", ClearSnapshots)
lib:RegisterCallback("exit", ClearSnapshots)
lib:RegisterCallback("layout", ClearSnapshots)

local POSITION_ROWS =
    { point = true, relativePoint = true, relativeTo = true, offsetX = true, offsetY = true, scale = true }

local function TrackSettings(frame, sections)
    local snapshots = settingSnapshots[frame] or {}
    settingSnapshots[frame] = snapshots
    for _, section in ipairs(sections) do
        for _, row in ipairs(section.options or {}) do
            -- Position has its own validated, ordered restore path; the Size section's disabled
            -- Scale placeholder has no value. Page rows merged into Size are settings.
            local position = (section.id == "position" or section.id == "position:size")
                and not row.setting
                and POSITION_ROWS[row.key]
            if row.get and row.set and not position then
                local key = section.id .. ":" .. row.key
                local snapshot = snapshots[key]
                if not snapshot then
                    snapshot = { value = row.get() }
                    snapshots[key] = snapshot
                end
                snapshot.row = row
            end
        end
    end
end

local function SettingsChanged(frame, restore)
    local changed = false
    for _, snapshot in pairs(settingSnapshots[frame] or {}) do
        local row = snapshot.row
        if row.get() ~= snapshot.value then
            changed = true
            if restore then
                (row.restore or row.set)(snapshot.value)
            end
        end
    end
    return changed
end

-- The shared Position section (editmodeposition.lua) for a Position setting of a suite frame,
-- bound to the feature's spec: the same controls as on Blizzard frames.
local function PositionSection(data, frame)
    local cached = positionSections[data]
    if cached and cached.frame == frame then
        return cached.section
    end
    local spec = data.position
    local function canEdit()
        return not (spec.disabled and spec.disabled()) and not InCombatLockdown() and lib:IsInEditMode()
    end
    local function read()
        local values = {}
        for _, field in ipairs(POSITION_FIELDS) do
            values[field[2]] = spec.get(field[1])
        end
        return values
    end
    local function differs(values)
        local current = read()
        for _, field in ipairs(POSITION_FIELDS) do
            if tostring(current[field[2]]) ~= tostring(values[field[2]]) then
                return true
            end
        end
        return false
    end
    -- Writes only what changed, so a feature rebuilds once per edit. Typed offsets arrive as text.
    local function apply(values)
        if not canEdit() then
            return false
        end
        local x, y = tonumber(values.offsetX), tonumber(values.offsetY)
        if not Finite(x) or not Finite(y) then
            return false, L["X and Y must be finite numbers."]
        end
        values.offsetX, values.offsetY = x, y
        local current = read()
        for _, field in ipairs(POSITION_FIELDS) do
            local value = values[field[2]]
            if tostring(current[field[2]]) ~= tostring(value) then
                spec.set(field[1], value)
            end
        end
        lib:RefreshFrameSettings(frame)
        return true
    end
    local function anchorFrames()
        local values = type(spec.anchorFrames) == "function" and spec.anchorFrames() or spec.anchorFrames
        return values or {}
    end
    local snapshot = read()
    local section = addon:CreateEditModePositionSection("position", {
        frame = frame,
        isCurrent = function()
            local selection = internal.dialog and internal.dialog.selection
            return selection ~= nil and selection.parent == frame
        end,
        canEdit = canEdit,
        read = read,
        apply = apply,
        anchorFrames = anchorFrames,
        anchorFrameText = function(value)
            for _, entry in ipairs(anchorFrames()) do
                if entry.value == value then
                    return entry.text
                end
            end
            return value ~= nil and tostring(value) or L["Unknown"]
        end,
        anchorFrame = spec.anchorFrame,
        isValidTarget = function(target)
            return target ~= frame and app.framePosition:IsValidAnchorTarget(target, frame)
        end,
        hasChanges = function()
            return differs(snapshot)
        end,
        -- A feature may reset by removing an override. Its preview's registered
        -- position can be a callback sentinel, not the client's default anchor.
        default = function(key)
            if spec.default then
                return spec.default(key == "offsetX" and "x" or key == "offsetY" and "y" or key)
            end
            local position, parent = DefaultPosition(frame), frame:GetParent()
            local defaults = {
                point = position.point,
                relativePoint = position.point,
                relativeTo = parent and parent.GetName and parent:GetName() or nil,
                offsetX = position.x,
                offsetY = position.y,
            }
            return defaults[key]
        end,
        revert = function()
            return apply(snapshot)
        end,
    })
    -- The feature's own rows sit at the top of the section, under its header.
    for index, extra in ipairs(data.options or {}) do
        table.insert(section.options, index, ConvertSetting(extra, "position" .. index, frame))
    end
    positionSections[data] = { frame = frame, section = section }
    return section
end

---@class SeamlessCore.EditModeAttachedSettings
---@field anchor table The dialog the window attaches below; the window takes its width.
---@field title string
---@field key any What is shown (a Blizzard system); the list scrolls back to the top when it changes.
---@field sections fun(): SeamlessCore.EditModeSection[] Built again on every layout.
---@field changed? fun() Called after a row changed a value (default: lay the window out again).
---@field buttonSection? SeamlessCore.EditModeButtonSection Explicit frame config declaration.
---@field buttonBinding? SeamlessCore.EditModeButtonBinding Native position action callbacks.

---@class SeamlessCore.EditModeButtonBinding
---@field canEdit fun(): boolean
---@field hasChanges fun(): boolean
---@field revert fun(): boolean, string?
---@field isDefault fun(): boolean
---@field reset fun(): boolean, string?

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
        local function reset(data)
            if data.kind == lib.SettingType.Option then
                data.row.setting:Reset()
            elseif data.set then
                data.set(lib:GetActiveLayoutName(), data.default, true)
            end
        end
        local settings = internal:GetFrameSettings(window.selection.parent)
        for _, data in ipairs(settings or {}) do
            reset(data)
            -- Reset To Default leaves the position alone, but not the feature's rows beside it.
            if data.kind == lib.SettingType.Position then
                for _, extra in ipairs(data.options or {}) do
                    reset(extra)
                end
            end
        end
    end

    -- The selected frame's settings, one section per header or Position, then Reset To Default.
    local function ListSections(frame)
        local settings, count = internal:GetFrameSettings(frame)
        local sections = { { id = "settings", options = {} } }
        for index, data in ipairs(settings or {}) do
            if data.kind == lib.SettingType.ButtonSection then
                -- Explicit footer declarations are drawn separately, outside the scrolling list.
            elseif data.kind == lib.SettingType.Position then
                local position = PositionSection(data, frame)
                sections[#sections + 1] = position
                sections[#sections + 1] = position.sizeSection
                -- Rows after it, up to the next header, go below without a header of their own.
                sections[#sections + 1] = { id = "after:" .. index, options = {} }
            elseif data.kind == lib.SettingType.Header then
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
            },
        }
        return sections
    end

    -- Draw only declared footer sections, outside the scrolling list.
    local function ButtonSections(frame, declared)
        local sections = {}
        local settings = declared and { declared } or internal:GetFrameSettings(frame)
        for index, data in ipairs(settings or {}) do
            if data.kind == lib.SettingType.ButtonSection and #data.options > 0 then
                local function allHidden()
                    for _, button in ipairs(data.options) do
                        if not Resolve(button.hidden) then
                            return false
                        end
                    end
                    return true
                end
                local options = { { key = "divider", type = "divider", hidden = allHidden } }
                for buttonIndex, button in ipairs(data.options) do
                    options[#options + 1] = ConvertSetting(button, "footer:" .. index .. ":" .. buttonIndex, frame)
                end
                sections[#sections + 1] = { id = "buttons:" .. index, options = options }
            end
        end
        return sections
    end

    ---Draw the selected frame's settings (or the attached sections) and size the window to them,
    ---growing downward only.
    function window:LayoutContent()
        local profile = app.db and app.db.profile
        if profile ~= snapshotProfile then
            ClearSnapshots()
            snapshotProfile = profile
        end
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
        TrackSettings(attached and attached.key or frame, sections)
        local changed = attached and attached.changed or Redraw
        local listHeight = addon:LayoutEditModeSections(list, sections, 0, false, changed)
        list:SetHeight(math.max(1, listHeight))
        local maximum = math.floor(math.min(MAX_HEIGHT, UIParent:GetHeight() * MAX_HEIGHT_SHARE))
        local scrollHeight = math.min(listHeight, maximum)
        scroll:SetHeight(math.max(1, scrollHeight))
        local footer = {}
        if not attached or attached.buttonSection then
            footer = ButtonSections(attached and attached.key or frame, attached and attached.buttonSection)
        end
        local buttonsHeight = addon:LayoutEditModeSections(buttons, footer, 0, false, changed)
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
    -- height. Poll suite frames too, so dragging and changes elsewhere update Revert.
    local elapsed = 0
    window:SetScript("OnUpdate", function(self, delta)
        if not self.attached and not self.selection then
            return
        end
        elapsed = elapsed + delta
        if elapsed >= POLL then
            elapsed = 0
            if addon:RefreshEditModeSections(list) or addon:RefreshEditModeSections(buttons) then
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

---@return string
function addon:GetEditModePositionSectionKey()
    return POSITION_SECTION
end

---A frame setting for LibEditMode's AddFrameSettings: the shared Position section (Scale, Anchor,
---AnchorParent, AnchorFrame, X, Y and "Quick anchor to frame"), the same one Blizzard frames
---get, with its collapse key `core:GetEditModePositionSectionKey()`.
---`spec.get(key)` and `spec.set(key, value)` use the keys point, relativePoint, relativeTo, x and
---y; `spec.anchorFrames()` returns `{ text, value }` entries for relativeTo, and the optional
---`spec.anchorFrame(value)` returns the frame of an entry (default: the global of that name).
---Its Size section shows a disabled Scale placeholder. Declare Revert separately with GetEditModeButtonSection. `options` are LibEditMode settings
---shown at the top of the section.
---@param spec SeamlessCore.EditModePosition
---@param options? table[]
---@return table setting
function addon:GetEditModePositionSetting(spec, options)
    return { kind = lib.SettingType.Position, name = L["Position"], position = spec, options = options }
end

---@class SeamlessCore.EditModeButtonSection
---@field kind "seamless-button-section"
---@field options SeamlessCore.EditModeButton[] Explicit Button settings, in display order.

---@class SeamlessCore.EditModeButton
---@field kind? "seamless-button" Filled by GetEditModeButtonSection when omitted.
---@field name string
---@field click fun(frame: table)
---@field desc? string
---@field hidden? boolean|fun(layout: string): boolean
---@field disabled? boolean|fun(layout: string): boolean

---An explicit, ordered list of arbitrary button declarations. No actions are inferred.
---@param buttons SeamlessCore.EditModeButton[]
---@return SeamlessCore.EditModeButtonSection
function addon:GetEditModeButtonSection(buttons)
    for _, button in ipairs(buttons) do
        assert(
            type(button) == "table" and type(button.name) == "string" and type(button.click) == "function",
            "Edit Mode buttons need a name and click callback"
        )
        button.kind = button.kind or lib.SettingType.Button
        assert(button.kind == lib.SettingType.Button, "Button sections only accept buttons")
    end
    return { kind = lib.SettingType.ButtonSection, options = buttons }
end

---Optional reusable position action, usable anywhere in an explicit button list.
---@param action "revert"|"resetPosition"
---@return SeamlessCore.EditModeButton
function addon:GetEditModePositionButton(action)
    assert(action == "revert" or action == "resetPosition", "Unknown Edit Mode position action")
    local function position(frame)
        local settings = internal:GetFrameSettings(frame)
        for _, setting in ipairs(settings or {}) do
            if setting.kind == lib.SettingType.Position then
                return PositionSection(setting, frame)
            end
        end
    end
    return {
        kind = lib.SettingType.Button,
        name = action == "revert" and (HUD_EDIT_MODE_REVERT_CHANGES or L["Revert changes"])
            or HUD_EDIT_MODE_RESET_POSITION,
        disabled = function()
            local dialog = internal.dialog
            local frame = dialog
                and (dialog.selection and dialog.selection.parent or dialog.attached and dialog.attached.key)
            if not frame or InCombatLockdown() or not lib:IsInEditMode() then
                return true
            end
            local binding = dialog and dialog.attached and dialog.attached.buttonBinding
            if binding then
                return not binding.canEdit()
                    or (action == "revert" and not binding.hasChanges() and not SettingsChanged(frame))
                    or (action == "resetPosition" and binding.isDefault())
            end
            if action == "resetPosition" then
                return fixedFrames[frame] == true or IsDefaultPosition(frame)
            end
            local section = position(frame)
            return (not section or section.revertButton.disabled()) and not SettingsChanged(frame)
        end,
        click = function(frame)
            local dialog = internal.dialog
            local current = dialog
                and (dialog.selection and dialog.selection.parent or dialog.attached and dialog.attached.key)
            if InCombatLockdown() or not lib:IsInEditMode() or current ~= frame then
                return
            end
            local binding = dialog.attached and dialog.attached.buttonBinding
            if binding then
                if binding.canEdit() then
                    if action == "revert" then
                        if binding.hasChanges() and binding.revert() == false then
                            return
                        end
                        SettingsChanged(frame, true)
                        dialog:LayoutContent()
                    else
                        binding.reset()
                    end
                end
                return
            end
            if action == "resetPosition" then
                if not fixedFrames[frame] then
                    ResetPosition(frame)
                end
            else
                local section = position(frame)
                if section and not section.revertButton.disabled() then
                    section.revertButton.click()
                end
                SettingsChanged(frame, true)
                dialog:LayoutContent()
            end
        end,
    }
end
