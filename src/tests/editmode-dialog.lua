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
    "SetOnClickHandler",
    "SetEnabled",
    "SetPropagateMouseMotion",
    "OnLoad",
    "SetHighlightTexture",
    "SetPushedTexture",
    "SetAllPoints",
    "EnableMouseWheel",
    "SetBlendMode",
    "SetAlpha",
    "AdjustPointsOffset",
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
    assert(name == nil)
    local frame = object(kind, parent, template)
    if template and template:find("ScrollFrameTemplate", 1, true) then
        frame.ScrollBar = object("EventFrame", frame)
    end
    if template == "UIPanelCloseButton" then
        frame.HookScript = function() end
    end
    return frame
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
assert(lib.SettingType.Header == "seamless-header")
assert(lib.internal:GetPool(lib.SettingType.Header), "Header widgets have a pool")

-- Second load must refuse silently overriding a library-defined Header.
assert(not pcall(assert(loadfile("Seamless/src/core/editmodelib.lua")), "Seamless", app))

local dialog = lib.internal:CreateDialog()
local scroll = dialog.SettingsScroll
assert(scroll and scroll.template == "ResizeLayoutFrame, ScrollFrameTemplate" and scroll.parent == dialog)
assert(scroll.points.TOP[1] == dialog.Title and scroll.points.TOP[4] == -12)
assert(scroll.ScrollBar.ignoreInLayout and scroll.ScrollBar.hideIfUnscrollable)
-- Blizzard's LayoutFrame GetSize ignores maximumHeight unless a minimum is set too.
assert(scroll.minimumHeight == 1)
assert(dialog.Settings.parent == scroll and scroll.scrollChild == dialog.Settings)
assert(next(dialog.Settings.points) == nil, "The scroll frame anchors its scroll child")
assert(dialog.Buttons.points.TOP[1] == scroll, "Buttons follow the scroll frame")

lib.isEditing = true
function lib:GetActiveLayoutName()
    return "Modern"
end
local frame = object("Frame", UIParent)
lib.frameSettings[frame] = {
    { kind = lib.SettingType.Header, name = "Section" },
    { kind = lib.SettingType.Divider, name = "Inside" },
    { kind = lib.SettingType.Header, name = "Hidden section", hidden = true },
    { kind = lib.SettingType.Divider, name = "After hidden header" },
}
lib.frameButtons[frame] = {}
function lib:GetFrameDefaultPosition()
    return { point = "CENTER", x = 0, y = 0 }
end
frame.GetPoint = function()
    return "CENTER", nil, nil, 0, 0
end
local selection = {
    parent = frame,
    system = {
        GetSystemName = function()
            return "Seamless Damage 1"
        end,
    },
}
scroll.verticalScroll = 50
dialog.Settings.height = 1000
frame.left, frame.right, frame.top = 100, 300, 600
dialog:Update(selection)
local placed = dialog.points.TOPLEFT
assert(placed[1] == UIParent and placed[3] == 316 and placed[4] == 600, "A new selection opens beside its frame")
assert(scroll.maximumHeight == 400, "Settings scroll past a fixed height, like Blizzard's container")
assert(scroll.fixedHeight == 400 and scroll.height == 400, "A long list scrolls at the cap")
assert(scroll.verticalScroll == 0, "A new selection starts at the top")
assert(dialog.Settings.fixedWidth == dialog.Settings.width, "The list keeps its fully expanded width")
local bar = scroll.ScrollBar
assert(bar.points.TOPLEFT[1] == scroll and bar.points.TOPLEFT[3] == 20 + 2, "Scroll bar sits outside the window")
assert(bar.points.BOTTOMLEFT[2] == "BOTTOMRIGHT" and bar.points.BOTTOMLEFT[3] == 22)
local widgets = dialog.Settings.widgets
local header, inside, hiddenHeader, after = widgets[1], widgets[2], widgets[3], widgets[4]
assert(header.kind == "Button" and header.Name.text == "Section" and header.Name.font == "GameFontNormalLeft")
assert(header.height == 28 and header.width == 330 and header.layoutIndex == 1 and header:IsShown())
assert(not hiddenHeader:IsShown() and after:IsShown(), "A hidden header collapses nothing")
assert(inside:IsShown() and header.StateIcon.atlas == "common-button-list-minus")
assert(header:GetParent():GetParent() == scroll)

scroll.verticalScroll = 50
dialog:Update(selection)
assert(scroll.verticalScroll == 50, "Refreshing the same selection keeps its scroll position")
-- Updating re-acquires pooled widgets, so read them again.
header, inside, hiddenHeader, after = widgets[1], widgets[2], widgets[3], widgets[4]

-- Clicking a header collapses its rows and remembers it for the next Update.
local layouts = dialog.layouts
local fixedWidth = dialog.Settings.fixedWidth
dialog.right, scroll.right = 400, 370
header.scripts.OnClick(header)
assert(dialog.Settings.fixedWidth == fixedWidth, "Collapsing keeps the width")
assert(bar.points.TOPLEFT[3] == 30 + 2, "Scroll bar follows the measured window edge")
assert(not inside:IsShown() and after:IsShown() and header:IsShown())
assert(header.StateIcon.atlas == "common-button-list-plus" and dialog.layouts == layouts + 2 and dialog:IsShown())
-- A short list shrinks the window and drops any scroll offset it no longer needs.
dialog.Settings.height = 120
dialog.left, dialog.top = 300, 700
layoutOrder = {}
dialog:RefreshWidgets()
local scrollIndex, dialogIndex
for index, frame in ipairs(layoutOrder) do
    if frame == scroll and not scrollIndex then
        scrollIndex = index
    end
    if frame == dialog then
        dialogIndex = index
    end
end
assert(scrollIndex and scrollIndex < dialogIndex, "The scroll frame resizes before the dialog measures its buttons")
local top = dialog.points.TOPLEFT
assert(top and top[1] == UIParent and top[2] == "BOTTOMLEFT" and top[3] == 300 and top[4] == 700)
assert(not dialog.points.BOTTOMRIGHT, "The dialog grows downward from its top edge")
assert(scroll.fixedHeight == 120 and scroll.verticalScroll == 0, "Collapsing shrinks the window")
dialog:Update(selection)
assert(not widgets[2]:IsShown(), "Collapsed sections stay collapsed")
widgets[1]:Toggle()
assert(widgets[2]:IsShown())
header, inside, hiddenHeader, after = widgets[1], widgets[2], widgets[3], widgets[4]

-- Widgets refresh through their grandparent; it must reach the dialog.
lib.frameSettings[frame][3].hidden = false
header:GetParent():GetParent():RefreshWidgets()
assert(hiddenHeader:IsShown())
-- Rows after a collapsed header stay hidden even when their own state refreshes.
hiddenHeader:Toggle()
assert(not after:IsShown())
assert(app.IsEditModeSectionCollapsed("settings:Hidden section"))
-- The shared Position section: a Position header, then Anchor, AnchorParent, AnchorFrame, X and Y.
local stored, locked = { point = "TOP", relativePoint = "TOP", relativeTo = "screen", x = 5, y = 6 }, false
local position = app.addon:GetEditModePositionSettings({
    get = function(key)
        return stored[key]
    end,
    set = function(key, value)
        stored[key] = value
    end,
    disabled = function()
        return locked
    end,
    anchorFrames = { { text = "Screen", value = "screen" } },
})
assert(#position == 6 and position[1].kind == lib.SettingType.Header and position[1].key == "position")
assert(app.addon:GetEditModePositionSectionKey() == "settings:position")
assert(position[2].name == "Anchor" and #position[2].values == 9 and position[4].height == 400)
assert(position[5].minValue == -1500 and position[5].maxValue == 1500 and position[6].maxValue == 1000)
assert(position[5].get() == 5 and position[5].formatter(4.6) == "5")
position[5].set(nil, 42)
assert(stored.x == 42)
position[5].set(nil, 0, true)
assert(stored.x == 42, "Reset To Default leaves the position alone")
locked = true
position[2].set(nil, "LEFT")
assert(stored.point == "TOP" and position[2].disabled(), "a locked position cannot change")
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
assert(not dialog.Buttons.ResetPositionButton:IsShown(), "no Reset Position")
dialog:Update({ parent = rightFrame, system = selection.system })
assert(dialog.Buttons.ResetPositionButton:IsShown(), "other frames keep Reset Position")
print("PASS: fixed frames are selectable but never move")
