-- Run from the repository root: lua src/tests/anchor-picker.lua
-- Drive Core's Edit Mode anchor picker: offsets, the two-step pick, hover choice and cancelling.
local methods = {}
local function object(kind, parent)
    return setmetatable({
        kind = kind,
        parent = parent,
        scripts = {},
        children = {},
        shown = true,
        width = 100,
        height = 50,
        left = 0,
    }, { __index = methods })
end
function methods:GetParent()
    return self.parent
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:Show()
    self.shown = true
end
function methods:Hide()
    self.shown = false
end
function methods:SetShown(value)
    self.shown = not not value
end
function methods:IsShown()
    return self.shown
end
function methods:IsVisible()
    return self.shown and (not self.parent or self.parent == UIParent or self.parent:IsVisible())
end
function methods:SetSize(width, height)
    self.width, self.height = width, height
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:GetLeft()
    return self.left
end
function methods:GetEffectiveScale()
    return 1
end
function methods:SetAllPoints(target)
    self.attached = target
end
function methods:IsMouseOver()
    if self.attached then
        return self.attached.mouseOver or false
    end
    return self.mouseOver or false
end
function methods:LockHighlight()
    self.locked = true
end
function methods:UnlockHighlight()
    self.locked = false
end
function methods:SetPropagateKeyboardInput(value)
    self.propagate = value
end
function methods:CreateFontString()
    return object("FontString", self)
end
function methods:CreateTexture()
    return object("Texture", self)
end
function methods:SetText(text)
    self.text = text
end
for _, name in ipairs({
    "ClearAllPoints",
    "SetPoint",
    "SetFrameStrata",
    "SetFrameLevel",
    "RegisterForClicks",
    "EnableKeyboard",
    "SetColorTexture",
    "SetNormalAtlas",
    "SetPushedAtlas",
    "SetHighlightAtlas",
}) do
    methods[name] = function() end
end

UIParent = object("Frame")
EditModeManagerFrame = object("Frame")
local combat = false
function InCombatLockdown()
    return combat
end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
function Mixin(target, ...)
    for index = 1, select("#", ...) do
        for key, value in pairs((select(index, ...))) do
            target[key] = value
        end
    end
    return target
end
function CreateFrame(kind, _, parent)
    return object(kind, parent)
end
dofile("src/tests/locale-support.lua")

local app = { addon = {} }
local toc = assert(io.open("Seamless/Seamless.toc")):read("*a")
assert(toc:find("src\\core\\anchorpicker.lua", 1, true), "The picker is listed in the TOC")
assert(loadfile("Seamless/src/core/anchorpicker.lua"))("Seamless", app)

-- Offsets keep a 5-pixel gap only on axes where the two points face each other.
local function offset(point, relativePoint, x, y)
    local ox, oy = app.GetAnchorPickerOffset(point, relativePoint)
    assert(ox == x and oy == y, ("%s -> %s gave %d, %d"):format(point, relativePoint, ox, oy))
end
offset("TOPLEFT", "BOTTOMRIGHT", 5, -5)
offset("BOTTOMRIGHT", "TOPLEFT", -5, 5)
offset("TOPLEFT", "TOPRIGHT", 5, 0)
offset("TOP", "BOTTOM", 0, -5)
offset("RIGHT", "LEFT", -5, 0)
offset("TOPLEFT", "TOPLEFT", 0, 0)
offset("CENTER", "RIGHT", 0, 0)
print("PASS: anchor picker offsets")

local source, big, small, hidden =
    object("Frame", UIParent), object("Frame", UIParent), object("Frame", UIParent), object("Frame", UIParent)
big.width, big.height = 400, 400
small.width, small.height = 40, 40
hidden.shown = false
local applied
local spec = {
    frame = source,
    targets = function()
        return {
            { frame = source, value = "source" },
            { frame = big, value = "big" },
            { frame = small, value = "small" },
            { frame = hidden, value = "hidden" },
        }
    end,
    apply = function(...)
        applied = { ... }
    end,
}
assert(app.StartAnchorPicker(spec) and app.IsAnchorPickerActive())

-- The picker keeps its frames private; reach them through the functions that use them.
local function upvalue(fn, wanted)
    local index = 1
    while true do
        local name, value = debug.getupvalue(fn, index)
        if not name then
            return nil
        end
        if name == wanted then
            return value
        end
        index = index + 1
    end
end
local catcher = upvalue(app.StartAnchorPicker, "catcher")
local sourceOverlay = upvalue(app.StartAnchorPicker, "sourceOverlay")
local update = catcher.scripts.OnUpdate
local targetOverlay = upvalue(update, "targetOverlay")
assert(catcher.shown and sourceOverlay.shown and sourceOverlay.attached == source)
assert(sourceOverlay.markerSize == 16, "Markers scale with the frame: a third of its smaller side")

-- Hovering another frame does nothing until a point on the selected frame is chosen.
big.mouseOver = true
update()
assert(not targetOverlay.shown)
sourceOverlay.markers.TOPLEFT.scripts.OnClick(sourceOverlay.markers.TOPLEFT, "LeftButton")
assert(sourceOverlay.markers.TOPLEFT.shown and not sourceOverlay.markers.CENTER.shown)
assert(sourceOverlay.markers.TOPLEFT.locked, "The chosen point stays highlighted")

-- The smallest hovered frame wins; hidden frames and the selected frame never get the overlay.
small.mouseOver, hidden.mouseOver, source.mouseOver = true, true, true
update()
assert(targetOverlay.shown and targetOverlay.attached == small and targetOverlay.markerSize == 13)
small.mouseOver = false
update()
assert(targetOverlay.attached == big)
targetOverlay.markers.BOTTOMRIGHT.scripts.OnClick(targetOverlay.markers.BOTTOMRIGHT, "LeftButton")
assert(applied[1] == "TOPLEFT" and applied[2] == "big" and applied[3] == "BOTTOMRIGHT")
assert(applied[4] == 5 and applied[5] == -5)
assert(not app.IsAnchorPickerActive() and not catcher.shown)
print("PASS: anchor picker two-step pick")

-- Right-click, Escape, combat and leaving Edit Mode cancel without applying.
applied = nil
app.StartAnchorPicker(spec)
catcher.scripts.OnClick(catcher, "RightButton")
assert(not app.IsAnchorPickerActive())
app.StartAnchorPicker(spec)
catcher.scripts.OnKeyDown(catcher, "LSHIFT")
assert(app.IsAnchorPickerActive() and catcher.propagate == true, "Other keys reach the game")
catcher.scripts.OnKeyDown(catcher, "ESCAPE")
assert(not app.IsAnchorPickerActive() and catcher.propagate == false, "Escape does not close Edit Mode")
app.StartAnchorPicker(spec)
sourceOverlay.markers.LEFT.scripts.OnClick(sourceOverlay.markers.LEFT, "RightButton")
assert(not app.IsAnchorPickerActive())
app.StartAnchorPicker(spec)
EditModeManagerFrame.shown = false
update()
assert(not app.IsAnchorPickerActive())
EditModeManagerFrame.shown = true
app.StartAnchorPicker(spec)
combat = true
update()
assert(not app.IsAnchorPickerActive() and not app.StartAnchorPicker(spec))
assert(applied == nil)
print("PASS: anchor picker cancelling")
