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
function methods:SetHideIfUnscrollable(value)
    self.hideIfUnscrollable = value
end
function methods:Layout()
    self.layouts = (self.layouts or 0) + 1
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
    { kind = lib.SettingType.Header, name = "Hidden section", hidden = true },
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
dialog:Update(selection)
assert(scroll.maximumHeight == 600, "Settings may use 60% of the screen height")
assert(scroll.verticalScroll == 0, "A new selection starts at the top")
local header, hiddenHeader = dialog.Settings.widgets[1], dialog.Settings.widgets[2]
assert(header.Label.text == "Section" and header.Label.font == "GameFontNormalLarge")
assert(header.height == 32 and header.layoutIndex == 1 and header:IsShown())
assert(not hiddenHeader:IsShown())
assert(header:GetParent():GetParent() == scroll)

scroll.verticalScroll = 50
dialog:Update(selection)
assert(scroll.verticalScroll == 50, "Refreshing the same selection keeps its scroll position")

-- Widgets refresh through their grandparent; it must reach the dialog.
lib.frameSettings[frame][2].hidden = false
header:GetParent():GetParent():RefreshWidgets()
assert(hiddenHeader:IsShown())
print("PASS: namespaced LibEditMode header widget, scrolling settings dialog and widget refresh")
