-- Run from the repository root: lua src/tests/editmode-dialog.lua
-- Load the real namespaced LibEditMode and Core's extension, then drive the settings dialog.
local methods = {}
local frames = {}
local function object(kind, parent, template)
    local frame = setmetatable({
        kind = kind,
        parent = parent,
        template = template,
        scripts = {},
        points = {},
        shown = true,
        width = 1,
        height = 1,
    }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:SetParent(parent)
    self.parent = parent
end
function methods:GetParent()
    return self.parent
end
function methods:GetChildren()
    local children = {}
    for _, child in ipairs(frames) do
        if child.parent == self then
            children[#children + 1] = child
        end
    end
    return unpack(children)
end
function methods:SetPoint(point, ...)
    self.points[point] = { ... }
end
function methods:ClearAllPoints()
    self.points = {}
end
function methods:SetSize(width, height)
    self.width, self.height = width, height
end
function methods:SetWidth(width)
    self.width = width
end
function methods:SetHeight(height)
    self.height = height
end
function methods:GetHeight()
    return self.height
end
function methods:GetWidth()
    return self.width
end
function methods:GetRight()
    return self.right
end
function methods:GetEffectiveScale()
    return self.scale or 1
end
function methods:GetLeft()
    return self.left
end
function methods:GetTop()
    return self.top
end
function methods:SetShown(value)
    self.shown = not not value
end
function methods:Show()
    self.shown = true
end
function methods:Hide()
    self.shown = false
end
function methods:IsShown()
    return self.shown
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:HookScript(event, callback)
    self.scripts[event] = callback
end
function methods:CreateFontString(_, _, font)
    local text = object("FontString", self)
    text.font = font
    return text
end
function methods:CreateTexture()
    return object("Texture", self)
end
function methods:SetText(text)
    self.text = text
end
function methods:GetText()
    return self.text
end
function methods:SetScrollChild(child)
    self.scrollChild = child
end
function methods:SetVerticalScroll(offset)
    self.verticalScroll = offset
end
function methods:GetVerticalScroll()
    return self.verticalScroll or 0
end
function methods:GetVerticalScrollRange()
    local child = self.scrollChild
    return child and math.max(0, child.height - self.height) or 0
end
-- The dialog's Layout sizes the scroll frame to its fixed size before the rect updates.
function methods:UpdateScrollChildRect()
    self.height = self.fixedHeight or self.height
end
function methods:SetHideIfUnscrollable(value)
    self.hideIfUnscrollable = value
end
function methods:SetNormalTexture(texture)
    self.normalTexture = texture
end
function methods:SetAtlas(atlas)
    self.atlas = atlas
end
local layoutOrder = {}
function methods:Layout()
    layoutOrder[#layoutOrder + 1] = self
    self.layouts = (self.layouts or 0) + 1
    if self.fixedHeight then
        self.height = self.fixedHeight
    end
end
function methods:SetupMenu(generator)
    self.generator = generator
end
function methods:SetDefaultText(text)
    self.defaultText = text
end
function methods:SetChecked(value)
    self.checked = value
end
function methods:Init(value, min, max, steps)
    self.value, self.min, self.max, self.steps = value, min, max, steps
end
function methods:SetTextColor() end
function methods:GetStringHeight()
    return 12
end
function methods:HasFocus()
    return false
end
function methods:SetOnClickHandler(callback)
    self.click = callback
end
function methods:SetEnabled(value)
    self.enabled = value
end
for _, name in ipairs({
    "SetFrameStrata",
    "SetFrameLevel",
    "EnableMouse",
    "SetMovable",
    "SetClampedToScreen",
    "SetDontSavePosition",
    "RegisterForDrag",
    "SetTexture",
    "SetJustifyH",
    "SetJustifyV",
    "GenerateMenu",
    "SetWordWrap",
    "SetScrollMode",
    "SetPropagateKeyboardInput",
    "SetPropagateMouseMotion",
    "OnLoad",
    "SetHighlightTexture",
    "SetPushedTexture",
    "SetAllPoints",
    "EnableMouseWheel",
    "SetBlendMode",
    "SetAlpha",
    "AdjustPointsOffset",
    "SetColorTexture",
    "SetAutoFocus",
    "SetMaxLetters",
    "SetCursorPosition",
    "ClearFocus",
}) do
    methods[name] = function() end
end

UIParent = object("Frame")
UIParent.height = 1000
LibStub = function()
    error("Namespaced LibEditMode must never use LibStub")
end
EventRegistry = { RegisterCallback = function() end, RegisterFrameEventAndCallback = function() end }
EditModeManagerFrame = { HookScript = function() end }
EditModeSystemSettingsDialog = { HookScript = function() end }
DefaultTooltipMixin = {}
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
function hooksecurefunc() end
function table.wipe(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end
local mouseDown = false
function IsMouseButtonDown(button)
    return button == "LeftButton" and mouseDown
end
function methods:IsVisible()
    return self.shown
end
function methods:IsMouseOver()
    return self.mouseOver
end
function InCombatLockdown()
    return false
end
RESET_TO_DEFAULT, HUD_EDIT_MODE_RESET_POSITION = "Reset To Default", "Reset Position"
Enum = { EditModeSettingDisplayType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4 } }
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end
function Mixin(target, ...)
    for index = 1, select("#", ...) do
        for key, value in pairs((select(index, ...))) do
            target[key] = value
        end
    end
    return target
end
function GenerateClosure(callback, owner)
    return function(...)
        return callback(owner, ...)
    end
end
function CreateUnsecuredObjectPool(create, reset)
    -- Methods read from self: the library reuses one pool's Acquire for every pool.
    local pool = { active = {}, free = {}, create = create, reset = reset }
    function pool:Acquire()
        local obj = table.remove(self.free)
        local new = not obj
        obj = obj or self.create(self)
        self.active[#self.active + 1] = obj
        return obj, new
    end
    function pool:ReleaseAll()
        for _, obj in ipairs(self.active) do
            self.reset(self, obj)
            self.free[#self.free + 1] = obj
        end
        self.active = {}
    end
    return pool
end
function CreateFrame(kind, name, parent, template)
    -- Only the settings dialog is a public frame.
    assert(name == nil or (name == "SeamlessEditModeSettingsDialog" and parent == UIParent and not _G[name]))
    local frame = object(kind, parent, template)
    if name then
        frame.name = name
        _G[name] = frame
    end
    if template and template:find("ScrollFrameTemplate", 1, true) then
        frame.ScrollBar = object("EventFrame", frame)
    end
    if template == "UIPanelCloseButton" then
        frame.HookScript = function(self, event, callback)
            self.scripts[event] = callback
        end
    end
    -- The row templates the shared renderer uses.
    if template == "EditModeSettingCheckboxTemplate" then
        frame.Button, frame.Label = object("CheckButton", frame), frame:CreateFontString()
    elseif template == "EditModeSettingSliderTemplate" then
        frame.Label, frame.Slider = frame:CreateFontString(), object("Slider", frame)
        frame.Slider.MinText, frame.Slider.MaxText = object("FontString", frame), object("FontString", frame)
        frame.Slider.RightText = object("FontString", frame)
        frame.cbrHandles = {
            Unregister = function() end,
            RegisterCallback = function(_, _, _, callback)
                frame.onValueChanged = callback
            end,
        }
    end
    return frame
end
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = 1 }, Label = { Right = 1 } }
function CreateMinimalSliderFormatter(_, formatter)
    return formatter
end
WHITE_FONT_COLOR, DISABLED_FONT_COLOR = { GetRGB = function() end }, { GetRGB = function() end }
function IsShiftKeyDown()
    return false
end

local app = {}
assert(loadfile("Seamless/lib/LibEditMode/namespaced.lua"))("Seamless", app)
local embed = assert(io.open("Seamless/lib/LibEditMode/embed.xml")):read("*a")
for path in embed:gmatch("file='([^']+)'") do
    assert(loadfile("Seamless/lib/LibEditMode/" .. path:gsub("\\", "/")))("Seamless", app)
end
dofile("src/tests/locale-support.lua")
app.addon = {}
UIParent.width = 1500
local toc = assert(io.open("Seamless/Seamless.toc")):read("*a")
local tocAce = assert(toc:find("src\\core\\ace.lua", 1, true))
local tocExtension = assert(toc:find("src\\core\\editmodelib.lua", 1, true))
local tocPanel = assert(toc:find("src\\core\\editmode.lua", 1, true))
assert(tocAce < tocExtension and tocExtension < tocPanel, "Extension loads before any Edit Mode user")
assert(loadfile("Seamless/src/core/editmodelib.lua"))("Seamless", app)
local lib = app.LibEditMode
assert(lib.SettingType.Header == "seamless-header" and lib.SettingType.Button == "seamless-button")
-- Core's real row renderer draws the window; the Position section file defines the anchor points.
assert(loadfile("Seamless/src/core/editmoderows.lua"))("Seamless", app)
assert(loadfile("Seamless/src/core/editmodeposition.lua"))("Seamless", app)

-- Second load must refuse silently overriding a library-defined Header.
assert(not pcall(assert(loadfile("Seamless/src/core/editmodelib.lua")), "Seamless", app))

-- The library's dialog is our window, a public frame of the library dialog's width.
local dialog = lib.internal:CreateDialog()
-- As AddFrame stores it.
lib.internal.dialog = dialog
assert(SeamlessEditModeSettingsDialog == dialog and dialog.name == "SeamlessEditModeSettingsDialog")
assert(dialog.parent == UIParent and dialog.width == 370 and not dialog:IsShown())
local scroll, list, buttons = dialog.Scroll, dialog.List, dialog.Buttons
assert(scroll.template == "ScrollFrameTemplate" and scroll.scrollChild == list)
assert(scroll.ScrollBar.hideIfUnscrollable, "the scroll bar hides when nothing scrolls")
local bar = scroll.ScrollBar
assert(bar.points.TOPLEFT[1] == scroll and bar.points.TOPLEFT[2] == "TOPRIGHT" and bar.points.TOPLEFT[3] == 2)
assert(buttons.points.TOPLEFT[1] == scroll, "the buttons stay in view below the list")

-- Rows of every row type the suite uses: what each window draws is checked through these frames.
local function ShownRows(parent, template)
    local rows = {}
    for _, candidate in ipairs(frames) do
        if candidate.parent == parent and candidate.option and candidate:IsShown() then
            if not template or candidate.template == template then
                rows[#rows + 1] = candidate
            end
        end
    end
    return rows
end
local function Row(parent, name)
    for _, candidate in ipairs(ShownRows(parent)) do
        if candidate.option.name == name then
            return candidate
        end
    end
end
local function Header(parent, text)
    for _, candidate in ipairs(frames) do
        if candidate.parent == parent and candidate.Name and candidate.Name.text == text then
            return candidate
        end
    end
end

lib.isEditing = true
function lib:GetActiveLayoutName()
    return "Modern"
end
local frame = object("Frame", UIParent)
local store, refreshes = { on = true, size = 10, style = "a" }, 0
local function accessors(key)
    return function(layout)
        assert(layout == "Modern", "settings read and write the active layout")
        return store[key]
    end, function(layout, value, fromReset)
        assert(layout == "Modern")
        store[key], store.fromReset = value, fromReset
    end
end
local getOn, setOn = accessors("on")
local getSize, setSize = accessors("size")
local getStyle, setStyle = accessors("style")
local clicked
lib.frameSettings[frame] = {
    { kind = lib.SettingType.Checkbox, name = "On", get = getOn, set = setOn, default = false, desc = "Tip" },
    { kind = lib.SettingType.Header, name = "Section" },
    {
        kind = lib.SettingType.Slider,
        name = "Size",
        get = getSize,
        set = function(layout, value, fromReset)
            setSize(layout, value, fromReset)
            -- Features refresh the window from their setters.
            refreshes = refreshes + 1
            lib:RefreshFrameSettings(frame)
        end,
        default = 5,
        minValue = 0,
        maxValue = 20,
        valueStep = 2,
        formatter = tostring,
    },
    {
        kind = lib.SettingType.Dropdown,
        name = "Style",
        get = getStyle,
        set = setStyle,
        default = "a",
        values = { { text = "A", value = "a" }, { text = "B", value = "b" } },
        height = 300,
        disabled = function(layout)
            return layout == "Modern" and not store.on
        end,
    },
    {
        kind = lib.SettingType.Button,
        name = "Do it",
        click = function(target)
            clicked = target
        end,
    },
    { kind = lib.SettingType.Header, name = "Hidden section", hidden = true },
    { kind = lib.SettingType.Checkbox, name = "After hidden header", get = getOn, set = setOn, default = false },
}
local buttonClicks = 0
lib.frameButtons[frame] = {
    {
        text = "Feature button",
        click = function()
            buttonClicks = buttonClicks + 1
        end,
    },
}
function lib:GetFrameDefaultPosition()
    return { point = "CENTER", x = 0, y = 0 }
end
local framePoint = { "CENTER", nil, nil, 0, 0 }
frame.GetPoint = function()
    return unpack(framePoint)
end
local resetCallback
lib.frameCallbacks[frame] = function(_, _, point, x, y)
    resetCallback = { point, x, y }
end
local selection = {
    parent = frame,
    system = {
        GetSystemName = function()
            return "Seamless Damage 1"
        end,
    },
}
lib.frameSelections[frame] = selection
frame.left, frame.right, frame.top = 100, 300, 600
scroll.verticalScroll = 50
dialog:Update(selection)
assert(dialog:IsShown() and dialog.Title.text == "Seamless Damage 1")
local placed = dialog.points.TOPLEFT
assert(placed[1] == UIParent and placed[3] == 316 and placed[4] == 600, "A new selection opens beside its frame")
assert(scroll.verticalScroll == 0, "A new selection starts at the top")
-- Rows before the first header have none; a hidden header collapses nothing.
local on, after = Row(list, "On"), Row(list, "After hidden header")
assert(on.template == "EditModeSettingCheckboxTemplate" and on.Button.checked == true and on.option.desc == "Tip")
local hiddenHeader = Header(list, "Hidden section")
assert(after and not (hiddenHeader and hiddenHeader:IsShown()))
local section = Header(list, "Section")
assert(section:IsShown() and section.StateIcon.atlas == "common-button-list-minus")
local size, style = Row(list, "Size"), Row(list, "Style")
assert(size.template == "EditModeSettingSliderTemplate" and size.Slider.value == 10)
assert(size.Slider.min == 0 and size.Slider.max == 20 and size.Slider.steps == 10)
assert(style.Dropdown.defaultText == "A" and style.Dropdown.enabled)
local doIt = Row(list, "Do it")
assert(doIt.Button.template == "EditModeSystemSettingsDialogButtonTemplate" and doIt.Button.width == 200)
doIt.Button.click()
assert(clicked == frame, "a Button setting gets the selected frame")

-- Hovering a row lights it up and shows its tooltip with the default, on the row.
GameTooltip = { lines = {} }
function GameTooltip:SetOwner(owner)
    self.owner, self.lines, self.points = owner, {}, {}
end
function GameTooltip:ClearAllPoints()
    self.points = {}
end
function GameTooltip:SetPoint(point, relativeTo, relativePoint, x, y)
    self.points[point] = { relativeTo, relativePoint, x, y }
end
function GameTooltip:SetText(text)
    self.lines = { text }
end
function GameTooltip:AddLine(text)
    self.lines[#self.lines + 1] = text
end
function GameTooltip:Show()
    self.shown = true
end
function GameTooltip:Hide()
    self.shown = false
end
function GameTooltip:IsOwned(owner)
    return self.owner == owner
end
function GameTooltip:GetWidth()
    return 200
end
on.mouseOver = true
on.scripts.OnEnter(on)
assert(on.Hover and on.Hover.shown and GameTooltip.shown and GameTooltip.owner == on)
assert(GameTooltip.lines[1] == "On" and GameTooltip.lines[2] == "Tip")
assert(GameTooltip.lines[3] == "\n(Default: |cff8080ffDisabled|r)", GameTooltip.lines[3])
local tipPoint = GameTooltip.points.BOTTOMLEFT
assert(tipPoint[1] == on and tipPoint[2] == "TOPRIGHT", "the tooltip sits on the row's top-right corner")
-- Moving onto the checkbox keeps both; leaving the row ends them.
on.Button.scripts.OnLeave()
assert(on.Hover.shown and GameTooltip.shown)
on.mouseOver = false
on.Button.scripts.OnLeave()
assert(not on.Hover.shown and not GameTooltip.shown)
style.Dropdown.scripts.OnEnter()
assert(GameTooltip.lines[2] == "\n(Default: |cff8080ffA|r)", "a choice shows its label")
style.Dropdown.scripts.OnLeave()
assert(not style.Hover.shown and not GameTooltip.shown)
size.Slider.scripts.OnEnter()
assert(GameTooltip.lines[2] == "\n(Default: |cff8080ff5|r)" and size.Hover.shown)
assert(GameTooltip.points.BOTTOMLEFT[1] == size)
doIt.scripts.OnEnter(doIt)
assert(not doIt.Hover and GameTooltip.owner ~= doIt, "buttons without a description have no tooltip")
local reset = Row(list, "Reset To Default")
assert(reset and reset.Button.enabled and reset.Button.width == 200)
-- The frame's buttons and Reset Position sit below the list.
local feature, resetPosition = Row(buttons, "Feature button"), Row(buttons, "Reset Position")
assert(buttons:IsShown() and feature and resetPosition and not resetPosition.Button.enabled)
feature.Button.click()
assert(buttonClicks == 1)
-- The divider above them is static too: it opens the button area, never the scrolling list.
local function Divider(parent)
    for _, row in ipairs(ShownRows(parent)) do
        if row.option.type == "divider" then
            return row
        end
    end
end
assert(Divider(buttons) and not Divider(list), "the divider stays with the buttons")
assert(-Divider(buttons).points.TOPLEFT[2] < -feature.points.TOPLEFT[2], "above the buttons")

-- Settings write the active layout; disabled states follow.
on:OnCheckButtonClick()
assert(store.on == false and store.fromReset == false and not style.Dropdown.enabled)
local radios = {}
style.Dropdown.generator(nil, {
    SetScrollMode = function(_, height)
        radios.height = height
    end,
    CreateRadio = function(_, text, _, select)
        radios[text] = select
        return { SetEnabled = function() end }
    end,
})
assert(radios.height == 300)
radios.B()
assert(store.style == "b" and style.Dropdown.defaultText == "B")
-- A slider whose setter refreshes the window keeps its drag: it is not initialized again.
local inits = 0
local init = size.Slider.Init
function size.Slider:Init(...)
    inits = inits + 1
    return init(self, ...)
end
size.onValueChanged(nil, 14)
assert(store.size == 14 and refreshes == 1 and inits == 0, "the dragged slider is left alone")
assert(Row(list, "Size") == size, "rows are reused, never rebuilt")
size.Slider.Init = init
-- Every slider takes a typed value: clamped to its range and snapped to its step.
assert(size.EditBox and size.Slider.width == 175, "plain sliders have the input box too")
local function typeSize(text)
    size.EditBox.scripts.OnEditFocusGained(size.EditBox)
    size.EditBox:SetText(text)
    size.EditBox.scripts.OnEnterPressed(size.EditBox)
    size.EditBox.scripts.OnEditFocusLost(size.EditBox)
end
typeSize("7")
assert(store.size == 8, "typed values snap to the step")
typeSize("99")
assert(store.size == 20, "typed values stay inside the range")
typeSize("abc")
assert(store.size == 20, "text is refused")

-- Collapsing a section hides its rows, is remembered, and keeps the width.
scroll.verticalScroll = 0
section.scripts.OnClick(section)
assert(not size:IsShown() and not style:IsShown() and section.StateIcon.atlas == "common-button-list-plus")
assert(app.IsEditModeSectionCollapsed("settings:Section") and dialog.width == 370)
dialog:Update(selection)
assert(not size:IsShown(), "Collapsed sections stay collapsed")
section.scripts.OnClick(section)
assert(size:IsShown())

-- Refreshing the same selection keeps its place.
dialog.left, dialog.top = 320, 650
dialog:Update(selection)
local top = dialog.points.TOPLEFT
assert(top[1] == UIParent and top[2] == "BOTTOMLEFT" and top[3] == 320 and top[4] == 650)
assert(not dialog.points.BOTTOMRIGHT, "The dialog grows downward from its top edge")

-- A long list scrolls at the cap; the window is never taller than its parts.
local many = {}
for index = 1, 30 do
    many[index] = { kind = lib.SettingType.Checkbox, name = "Row " .. index, get = getOn, set = setOn }
end
local longFrame = object("Frame", UIParent)
longFrame.left, longFrame.right, longFrame.top, longFrame.GetPoint = 100, 300, 600, frame.GetPoint
lib.frameSettings[longFrame], lib.frameButtons[longFrame] = many, {}
local longSelection = { parent = longFrame, system = selection.system }
dialog:Update(longSelection)
assert(scroll.height == 400, "Settings scroll past a fixed height, like Blizzard's container")
assert(list.height > 400 and dialog.height == 15 + 20 + 12 + 400 + 12 + buttons.height + 20)
scroll.verticalScroll = 50
dialog:Update(longSelection)
assert(scroll.verticalScroll == 50, "Refreshing the same selection keeps its scroll position")
-- A shorter list drops any scroll offset it no longer needs.
for index = 5, 30 do
    many[index] = nil
end
scroll.verticalScroll = 1000
dialog:Update(longSelection)
assert(scroll.height < 400 and scroll.verticalScroll == 0, "the window shrinks with its list")
dialog:Update(selection)

-- Reset To Default writes every default with fromReset; Reset Position restores the default spot.
reset = Row(list, "Reset To Default")
reset.Button.click()
assert(store.on == false and store.size == 5 and store.style == "a" and store.fromReset == true)
framePoint = { "TOPLEFT", nil, nil, 40, -40 }
dialog:Update(selection)
assert(resetPosition.Button.enabled, "a moved frame can reset its position")
function frame:ClearAllPoints() end
function frame:SetPoint(point, x, y)
    framePoint = { point, nil, nil, x, y }
end
lib.activeLayout = 1
function securecallfunction(callback, ...)
    return callback(...)
end
resetPosition.Button.click()
assert(framePoint[1] == "CENTER" and resetCallback[1] == "CENTER" and not resetPosition.Button.enabled)

-- Arrow keys nudge the selected frame through the library; other keys pass through.
local nudged
local move = lib.internal.MoveParent
function lib.internal:MoveParent(target, x, y)
    nudged = { target, x, y }
end
dialog.scripts.OnKeyDown(dialog, "LEFT")
assert(nudged[1] == selection and nudged[2] == -1)
dialog.scripts.OnKeyDown(dialog, "UP")
assert(nudged[2] == 0 and nudged[3] == 1)
lib.internal.MoveParent = move

-- The close button resets the window like the library's dialog.
local close
for _, candidate in ipairs(frames) do
    if candidate.template == "UIPanelCloseButton" and candidate.parent == dialog then
        close = candidate
    end
end
close.scripts.OnClick(close)
assert(dialog.selection == nil and dialog.points.BOTTOMRIGHT)
dialog:Update(selection)

-- Only supported setting kinds: anything else fails loudly instead of disappearing.
local oddFrame = object("Frame", UIParent)
oddFrame.GetPoint = frame.GetPoint
lib.frameSettings[oddFrame], lib.frameButtons[oddFrame] = { { kind = lib.SettingType.Divider } }, {}
assert(not pcall(dialog.Update, dialog, { parent = oddFrame, system = selection.system }))
dialog:Update(selection)

-- The shared Position section, as a frame setting: the same section Blizzard frames get, with a
-- feature's own rows at its top and the rows after it below.
assert(app.addon:GetEditModePositionSectionKey() == "settings:position")
-- Position starts collapsed; opening it is remembered, and collapsing it again clears the entry.
assert(app.IsEditModeSectionCollapsed("settings:position"), "Position starts collapsed")
app.SetEditModeSectionCollapsed("settings:position", false)
assert(not app.IsEditModeSectionCollapsed("settings:position"))
app.SetEditModeSectionCollapsed("settings:position", true)
assert(app.IsEditModeSectionCollapsed("settings:position"))
do
    local otherWindow = object("Frame", UIParent)
    app.framePosition = {
        IsValidAnchorTarget = function(_, target)
            return target ~= nil
        end,
    }
    local picker
    function app.addon:StartEditModeAnchorPicker(spec)
        picker = spec
        return true
    end
    local stored, locked = { point = "TOP", relativePoint = "TOP", relativeTo = "screen", x = 5, y = 6 }, false
    local lock = { on = false }
    local setting = app.addon:GetEditModePositionSetting({
        get = function(key)
            return stored[key]
        end,
        set = function(key, value)
            stored[key] = value
        end,
        disabled = function()
            return locked
        end,
        anchorFrames = { { text = "Screen", value = "screen" }, { text = "Window 2", value = "2" } },
        anchorFrame = function(value)
            return value == "2" and otherWindow or value == "screen" and UIParent or nil
        end,
    }, {
        {
            kind = lib.SettingType.Checkbox,
            name = "Lock it",
            default = false,
            get = function()
                return lock.on
            end,
            set = function(_, value)
                lock.on = value
            end,
        },
    })
    assert(setting.kind == lib.SettingType.Position and setting.name == "Position")
    local positioned = object("Frame", UIParent)
    positioned.GetPoint = frame.GetPoint
    lib.frameSettings[positioned], lib.frameButtons[positioned] =
        {
            setting,
            { kind = lib.SettingType.Checkbox, name = "Below position", get = getOn, set = setOn, default = false },
        }, {}
    local positionSelection = { parent = positioned, system = selection.system, isSelected = true }
    lib.frameSelections[positioned] = positionSelection
    app.SetEditModeSectionCollapsed("settings:position", false)
    dialog:Update(positionSelection)
    local function top(row)
        return -row.points.TOPLEFT[2]
    end
    local lockRow, scaleRow, xRow = Row(list, "Lock it"), Row(list, "Scale"), Row(list, "X")
    assert(Header(list, "Position") and lockRow and scaleRow and xRow and Row(list, "Below position"))
    assert(top(lockRow) < top(scaleRow), "the feature's rows open the section")
    assert(top(Row(list, "Revert changes")) < top(Row(list, "Below position")), "later rows go below it")
    for _, name in ipairs({ "Anchor", "AnchorParent", "AnchorFrame", "Y", "Quick anchor to frame" }) do
        assert(Row(list, name), name)
    end
    -- Scale is greyed out without a binding; X and Y write through the feature, one field at a time.
    assert(scaleRow.option.disabled() and scaleRow.option.get() == 1)
    assert(xRow.option.get() == 5 and xRow.option.editable)
    -- Values show at most two decimals, and the slider leaves room for them inside the row.
    assert(xRow.option.format(-314.799987792969) == "-314.8" and xRow.option.format(1.006) == "1.01")
    assert(xRow.Slider.width == 175 and Row(list, "Scale").Slider.width == 175)
    xRow.value = -314.799987792969
    xRow.EditBox.scripts.OnEditFocusGained(xRow.EditBox)
    assert(xRow.EditBox.text == "-314.8", "typing starts from the shown value")
    xRow.EditBox.scripts.OnEditFocusLost(xRow.EditBox)
    local revert = Row(list, "Revert changes")
    assert(revert.option.disabled(), "nothing to revert yet")
    xRow.option.set("42")
    assert(stored.x == 42 and stored.y == 6 and not revert.option.disabled(), "typed values become numbers")
    xRow.option.set("abc")
    assert(stored.x == 42 and Row(list, "X") and Row(list, "X").option.get() == 42, "text is refused")
    locked = true
    Row(list, "Anchor").option.set("LEFT")
    assert(stored.point == "TOP", "a locked position cannot change")
    locked = false
    -- Revert restores the position the frame had when it was selected.
    revert.option.click()
    assert(stored.x == 5 and revert.option.disabled())
    -- Anchor choices resolve through the feature; the screen counts as UIParent.
    local entries = Row(list, "AnchorFrame").option.values()
    assert(#entries == 2 and not entries[1].disabled and not entries[2].disabled)
    -- A new button row has no width until the client lays it out; its button follows once it does.
    local quick = Row(list, "Quick anchor to frame")
    quick.scripts.OnSizeChanged(quick, 322)
    assert(quick.Button.width == 161, "the button takes half the row once it has a width")
    -- The anchor picker targets resolved frames but not UIParent, and writes all five values.
    quick.option.click()
    assert(picker and picker.frame == positioned)
    local targets = picker.targets()
    assert(#targets == 1 and targets[1].frame == otherWindow and targets[1].value == "2")
    picker.apply("TOPLEFT", "2", "BOTTOMRIGHT", 5, -5)
    assert(stored.relativeTo == "2" and stored.point == "TOPLEFT" and stored.relativePoint == "BOTTOMRIGHT")
    assert(stored.x == 5 and stored.y == -5)
    -- Reset To Default leaves the position alone, but resets the feature's rows in the section.
    lock.on = true
    Row(list, "Reset To Default").option.click()
    assert(lock.on == false and stored.point == "TOPLEFT", "Reset To Default keeps the position")
    -- A bound Scale writes through the feature's scale binding.
    local scaled = 1.5
    local scaledFrame = object("Frame", UIParent)
    scaledFrame.GetPoint = frame.GetPoint
    lib.frameSettings[scaledFrame], lib.frameButtons[scaledFrame] =
        {
            app.addon:GetEditModePositionSetting({
                get = function(key)
                    return stored[key]
                end,
                set = function() end,
                anchorFrames = {},
                scale = {
                    min = 0.75,
                    max = 1.5,
                    step = 0.05,
                    get = function()
                        return scaled
                    end,
                    set = function(value)
                        scaled = value
                    end,
                },
            }),
        }, {}
    local scaledSelection = { parent = scaledFrame, system = selection.system, isSelected = true }
    lib.frameSelections[scaledFrame] = scaledSelection
    dialog:Update(scaledSelection)
    local bound = Row(list, "Scale").option
    assert(not bound.disabled() and bound.get() == 1.5 and bound.min() == 0.75 and bound.max() == 1.5)
    bound.set("1.1")
    assert(scaled == 1.1)
    bound.set(3)
    assert(scaled == 1.1, "outside the binding's range")
    app.SetEditModeSectionCollapsed("settings:position", true)
    lib.frameSelections[positioned], lib.frameSelections[scaledFrame] = nil, nil
    dialog:Update(selection)
end
print("PASS: namespaced LibEditMode collapsible headers, scrolling settings dialog and widget refresh")

-- A frame near the right edge gets its settings on its left.
local rightFrame = object("Frame", UIParent)
rightFrame.left, rightFrame.right, rightFrame.top = 1300, 1450, 500
lib.frameSettings[rightFrame], lib.frameButtons[rightFrame] = {}, {}
rightFrame.GetPoint = frame.GetPoint
dialog.width = 340
dialog:Update({ parent = rightFrame, system = selection.system })
assert(dialog.points.TOPLEFT[3] == 1300 - 16 - 340 and dialog.points.TOPLEFT[4] == 500)
print("PASS: settings dialog opens beside the selected frame")

-- With the SeamlessUI option, a new selection opens beside Blizzard's Edit Mode window instead,
-- converted to the dialog's scale and kept on screen; Blizzard's dialog is placed the same way.
do
    local manager = object("Frame", UIParent)
    manager.right, manager.top, manager.shown = 400, 800, true
    manager.HookScript = EditModeManagerFrame.HookScript
    local savedManager = EditModeManagerFrame
    EditModeManagerFrame = manager
    app.addon:SetEditModeDialogsBesideManager(true)
    dialog:Update({ parent = frame, system = selection.system })
    assert(dialog.points.TOPLEFT[1] == UIParent and dialog.points.TOPLEFT[3] == 404)
    assert(dialog.points.TOPLEFT[4] == 800, "beside the Edit Mode window, aligned with its top")
    manager.right, manager.scale = 1400, 0.5
    dialog:Update({ parent = rightFrame, system = selection.system })
    assert(dialog.points.TOPLEFT[3] == 704 and dialog.points.TOPLEFT[4] == 400, "converted to the dialog's scale")
    manager.scale, manager.right = 1, 1400
    dialog:Update({ parent = frame, system = selection.system })
    assert(dialog.points.TOPLEFT[3] == 1500 - 340, "kept on screen")
    manager.shown = false
    dialog:Update({ parent = rightFrame, system = selection.system })
    assert(dialog.points.TOPLEFT[3] == 1300 - 16 - 340, "beside the frame while the window is hidden")
    manager.shown = true
    local native = object("Frame", UIParent)
    native.width, native.height = 300, 350
    manager.right = 400
    assert(app.addon:PlaceBesideEditModeManager(native) and native.points.TOPLEFT[3] == 404)
    app.addon:SetEditModeDialogsBesideManager(false)
    dialog:Update({ parent = frame, system = selection.system })
    assert(dialog.points.TOPLEFT[3] == 316, "off again: beside the frame")
    EditModeManagerFrame = savedManager
end
print("PASS: settings dialogs can open beside the Edit Mode window")

-- A fixed frame can be selected with its settings but never moved.
local fixedFrame, moved = object("Frame", UIParent), false
fixedFrame.left, fixedFrame.right, fixedFrame.top = 100, 250, 500
fixedFrame.GetPoint = frame.GetPoint
local layoutCache, isEditing = lib.layoutCache, lib.isEditing
lib.layoutCache, lib.isEditing = nil, false
lib:AddFrame(fixedFrame, function()
    moved = true
end, { point = "CENTER", x = 0, y = 0 }, "Fixed")
lib.layoutCache, lib.isEditing = layoutCache, isEditing
app.addon:SetEditModeFrameFixed(fixedFrame)
local fixedSelection = lib.frameSelections[fixedFrame]
assert(fixedSelection.scripts.OnDragStart == nil and fixedSelection.scripts.OnDragStop == nil, "no dragging")
lib.internal:MoveParent(fixedSelection, 5, 0)
assert(not moved, "no arrow-key nudges")
lib.frameSettings[fixedFrame], lib.frameButtons[fixedFrame] = {}, {}
dialog:Update({ parent = fixedFrame, system = selection.system })
assert(not Row(buttons, "Reset Position"), "no Reset Position")
assert(not buttons:IsShown(), "an empty button list is left out of the window")
dialog:Update({ parent = rightFrame, system = selection.system })
assert(buttons:IsShown() and Row(buttons, "Reset Position"), "other frames keep Reset Position")
print("PASS: fixed frames are selectable but never move")

-- Attached below Blizzard's settings dialog, the same window shows a feature's sections: no close
-- button, frame buttons or dragging, and it polls for changes made elsewhere.
do
    local native = object("Frame", UIParent)
    native.GetFrameLevel = function()
        return 50
    end
    function dialog:SetFrameLevel(level)
        self.frameLevel = level
    end
    local dragged = false
    function dialog:StartMoving()
        dragged = true
    end
    local on, changes = true, 0
    local spec = {
        anchor = native,
        key = "system",
        title = "SeamlessUI - Player frame",
        sections = function()
            return {
                {
                    id = "style",
                    name = "Style",
                    key = "settings:style",
                    options = {
                        {
                            key = "on",
                            type = "toggle",
                            name = "Attached on",
                            get = function()
                                return on
                            end,
                            set = function(value)
                                on = value
                            end,
                        },
                    },
                },
            }
        end,
        changed = function()
            changes = changes + 1
        end,
    }
    dialog:Update({ parent = frame, system = selection.system })
    app.addon:AttachEditModeSettingsWindow(spec)
    assert(dialog:IsShown() and dialog.attached == spec and dialog.selection == nil)
    assert(dialog.Title.text == "SeamlessUI - Player frame" and not dialog.Close:IsShown())
    local top = dialog.points.TOPLEFT
    assert(top[1] == native and top[2] == "BOTTOMLEFT" and top[4] == -8, "below the native dialog")
    assert(dialog.points.TOPRIGHT[1] == native, "as wide as the native dialog")
    assert(dialog.frameLevel == 60, "above the native dialog")
    local row = Row(list, "Attached on")
    assert(row and row.Button.checked == true and Header(list, "Style"))
    assert(not buttons:IsShown(), "no frame buttons")
    row:OnCheckButtonClick()
    assert(on == false and changes == 1, "rows write through the feature's sections")
    on = true
    dialog.scripts.OnUpdate(dialog, 0.2)
    assert(row.Button.checked == true, "the poll picks up changes made elsewhere")
    dialog.scripts.OnDragStart(dialog)
    assert(not dragged, "it follows the native dialog")
    -- Selecting a suite frame takes the window back; detaching then leaves it alone.
    dialog:Update({ parent = frame, system = selection.system })
    assert(dialog.attached == nil and dialog.Close:IsShown() and dialog.width == 370)
    assert(dialog.frameLevel == 200 and Row(buttons, "Reset Position"))
    dialog.scripts.OnDragStart(dialog)
    assert(dragged, "draggable again")
    app.addon:DetachEditModeSettingsWindow()
    assert(dialog:IsShown() and dialog.selection, "a suite frame's settings stay")
    -- A native selection: the library hides and resets the window, then the feature attaches it.
    app.addon:AttachEditModeSettingsWindow(spec)
    dialog:Hide()
    dialog:Reset()
    assert(dialog.attached == nil and dialog.Close:IsShown())
    app.addon:AttachEditModeSettingsWindow(spec)
    assert(dialog:IsShown() and dialog.attached == spec)
    app.addon:DetachEditModeSettingsWindow()
    assert(not dialog:IsShown() and dialog.attached == nil and dialog.selection == nil)
    dialog.SetFrameLevel, dialog.StartMoving = nil, nil
end
print("PASS: the window attaches below Blizzard's settings dialog")

print("PASS: suite frame settings window")
