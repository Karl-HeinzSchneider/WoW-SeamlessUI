-- Run from the repository root: lua src/tests/editmode-panel.lua
local frames, callbacks = {}, {}
local editing, combat = false, false
local nativeWidth = 510
local anchorsReady = false
local methods = {}
local function object(parent, template)
    local frame = setmetatable(
        { parent = parent, template = template, scripts = {}, points = {}, shown = true, height = 32 },
        { __index = methods }
    )
    frames[#frames + 1] = frame
    return frame
end
function methods:GetFrameLevel()
    return self.frameLevel or (self.parent and self.parent:GetFrameLevel() + 1 or 0)
end
function methods:SetFrameLevel(value)
    self.frameLevel = value
end
function methods:SetFontObject(value)
    self.fontObject = value
end
function methods:GetParent()
    return self.parent
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:HookScript(event, callback)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then
            original(...)
        end
        callback(...)
    end
end
function methods:RegisterEvent() end
function methods:SetFrameStrata(value)
    self.strata = value
end
function methods:EnableMouse() end
function methods:EnableMouseWheel() end
function methods:SetPoint(point, ...)
    self.points[point] = { ... }
end
function methods:ClearAllPoints()
    self.points = {}
end
function methods:SetAllPoints()
    self.allPoints = true
end
function methods:SetWidth(value)
    if self.width == value then
        return
    end
    self.width = value
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self)
    end
end
function methods:GetWidth()
    if self.points.TOPRIGHT and self.points.TOPRIGHT[1] == EditModeManagerFrame then
        return anchorsReady and nativeWidth or 0
    end
    return self.width or 1
end
function methods:SetHeight(value)
    if self.height == value then
        return
    end
    self.height = value
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self)
    end
end
function methods:GetHeight()
    return self.height
end
function methods:GetTop()
    return self.top
end
function methods:SetScrollChild(child)
    self.scrollChild = child
end
function methods:SetHideIfUnscrollable(value)
    self.hideIfUnscrollable = value
end
function methods:SetSize(width, height)
    self:SetWidth(width)
    self:SetHeight(height)
end
function methods:SetShown(value)
    if value then
        self:Show()
    else
        self:Hide()
    end
end
function methods:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then
        self.scripts.OnShow(self)
    end
end
function methods:Hide()
    self.shown = false
end
function methods:IsShown()
    return self.shown
end
function methods:CreateFontString()
    return object(self, "FontString")
end
function methods:SetText(value)
    self.text = value
end
function methods:SetTextColor() end
function methods:SetJustifyH() end
function methods:SetWordWrap() end
function methods:GetStringHeight()
    return math.max(1, math.ceil(#(self.text or "") * 7 / self:GetWidth())) * 16
end
function methods:SetChecked(value)
    self.checked = value
end
function methods:GetChecked()
    return self.checked
end
function methods:SetEnabled(value)
    self.enabled = value
end
UIParent = object()
EditModeManagerFrame = setmetatable({
    GetWidth = function()
        return nativeWidth
    end,
}, {
    __index = function()
        error("Do not read native layout internals")
    end,
    __newindex = function()
        error("Do not mutate native Edit Mode")
    end,
})
function CreateFrame(_, name, parent, template)
    assert(name == nil and parent ~= EditModeManagerFrame)
    local frame = object(parent or UIParent, template)
    if template == "DialogBorderTranslucentTemplate" then
        frame:SetFrameLevel(500)
    end
    if template == "ScrollFrameTemplate" then
        frame.ScrollBar = object(frame, "ScrollBar")
    end
    if template == "UICheckButtonTemplate" then
        frame.Text = object(frame, "FontString")
        frame.Text:Hide() -- Regression: refresh must make the actual label visible before a click.
    end
    return frame
end
function InCombatLockdown()
    return combat
end
WHITE_FONT_COLOR = {
    GetRGB = function()
        return 1, 1, 1
    end,
}
DISABLED_FONT_COLOR = WHITE_FONT_COLOR
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
local core = {}
-- Collapse helpers come from editmodelib.lua (covered by editmode-dialog.lua).
local collapsedSections = {}
local app = {
    IsEditModeSectionCollapsed = function(key)
        return collapsedSections[key] == true
    end,
    SetEditModeSectionCollapsed = function(key, value)
        collapsedSections[key] = value or nil
    end,
    CreateEditModeHeader = function(parent, onClick)
        local header = object(parent, "ListHeaderThreeSliceTemplate")
        header.Toggle = onClick
        function header:SetHeaderText(text)
            self.headerText = text
        end
        function header:UpdateCollapsedState(collapsed)
            self.collapsed = collapsed
        end
        return header
    end,
    addon = core,
    LibEditMode = {
        IsInEditMode = function()
            return editing
        end,
        RegisterCallback = function(_, event, callback)
            callbacks[event] = callback
        end,
    },
}
dofile("src/tests/locale-support.lua")
assert(loadfile("Seamless/src/core/editmode.lua"))("Seamless", app)
local enabled, hidden, value, clicked = true, false, true, 0
core:RegisterEditModeOptions("meter", {
    section = "frames",
    order = 20,
    enabled = function()
        return enabled
    end,
    options = {
        {
            key = "preview",
            type = "toggle",
            name = "Seamless Damage Meter",
            get = function()
                return value
            end,
            set = function(v)
                value = v
            end,
        },
    },
})
assert(not pcall(function()
    core:RegisterEditModeOptions("meter", {
        section = "frames",
        options = {},
    })
end))
editing = true
callbacks.enter()
local panel, toggle, border
for _, frame in ipairs(frames) do
    if frame.points.TOPRIGHT and frame.points.TOPRIGHT[1] == EditModeManagerFrame then
        panel = frame
    end
    if frame.template == "UICheckButtonTemplate" then
        toggle = frame
    end
    if frame.template == "DialogBorderTranslucentTemplate" then
        border = frame
    end
end
assert(panel and panel.parent == UIParent and panel.strata == "DIALOG")
assert(border and border.parent == panel and border.allPoints)
assert(panel.scripts.OnUpdate, "First show must schedule a layout pass after anchors/fonts settle")
assert(toggle.parent.Label:GetWidth() == 430, "Unresolved panel anchors must use the native window width")
anchorsReady = true
local pending = panel.scripts.OnUpdate
pending(panel)
assert(panel:GetWidth() == 510 and panel:GetHeight() == 124 and panel:IsShown())
local scroll
for _, frame in ipairs(frames) do
    if frame.template == "ScrollFrameTemplate" then
        scroll = frame
    end
end
assert(scroll and scroll.parent == panel and scroll.ScrollBar.hideIfUnscrollable)
assert(toggle.parent.parent == scroll.scrollChild, "Rows live in the scroll child")
assert(scroll.scrollChild:GetHeight() == 124 - 44 - 16 and scroll:GetHeight() == 124 - 44 - 16)
assert(panel.scripts.OnUpdate == nil, "Settled layout must stop updating")
assert(panel.points.TOPLEFT[3] == 0 and panel.points.TOPLEFT[4] == -8)
local foundTitle = false
for _, frame in ipairs(frames) do
    if frame.parent == panel and frame.text == "SeamlessUI" then
        foundTitle = true
    end
end
assert(foundTitle and toggle.checked)
assert(toggle.parent.Label == toggle.Text and toggle.Text:IsShown())
assert(toggle.Text.text == "Seamless Damage Meter")
assert(border:GetFrameLevel() < toggle:GetFrameLevel(), "Border must not cover checkbox text")
toggle:SetChecked(false)
toggle.scripts.OnClick(toggle)
assert(not value and not toggle.checked)
local otherEnabled = true
core:RegisterEditModeOptions("other", {
    enabled = function()
        return otherEnabled
    end,
    order = 100,
    name = "Custom options",
    options = {
        {
            key = "custom",
            type = "custom",
            create = function(parent)
                local row = CreateFrame("Frame", nil, parent)
                row:SetHeight(50)
                return row
            end,
        },
        {
            key = "button",
            type = "button",
            name = "Do something",
            hidden = function()
                return hidden
            end,
            click = function()
                clicked = clicked + 1
            end,
        },
    },
})
local custom, button
for _, frame in ipairs(frames) do
    if frame.option and frame.option.key == "custom" then
        custom = frame
    end
    if frame.template == "UIPanelButtonTemplate" then
        button = frame
    end
end
assert(custom.points.TOPLEFT[4] <= 0 and custom.points.TOPLEFT[4] > toggle.parent.points.TOPLEFT[4])
local heading
for _, frame in ipairs(frames) do
    if frame.text == "Frames" then
        heading = frame
    end
end
assert(heading and heading:IsShown())
assert(custom.points.TOPLEFT[4] > heading.points.TOPLEFT[4], "Options must precede Frames regardless of order")
assert(heading.points.TOPLEFT[4] > toggle.parent.points.TOPLEFT[4])
local expanded = panel:GetHeight()
-- Headers are section titles inside a group, sized like the Frames heading.
core:RegisterEditModeOptions("sections", {
    order = 200,
    options = {
        { key = "title", type = "header", name = "Section" },
        { key = "inside", type = "button", name = "Inside", click = function() end },
    },
})
local sectionHeader
for _, frame in ipairs(frames) do
    if frame.option and frame.option.key == "title" then
        sectionHeader = frame
    end
end
assert(sectionHeader and sectionHeader.headerText == "Section" and sectionHeader:GetHeight() == 26)
assert(sectionHeader.template == "ListHeaderThreeSliceTemplate" and not sectionHeader.collapsed)
assert(panel:GetHeight() == expanded + 32 + 38)
-- Clicking a header collapses the rows after it, and clicking again expands them.
sectionHeader.Toggle()
assert(collapsedSections["panel:sections:title"] and sectionHeader.collapsed)
assert(panel:GetHeight() == expanded + 32, "Collapsed rows reserve no space")
sectionHeader.Toggle()
assert(not collapsedSections["panel:sections:title"] and panel:GetHeight() == expanded + 32 + 38)
-- A panel near the screen bottom caps its height and scrolls the rest.
panel.top = 44 + 16 + 8 + 100
core:RefreshEditModeOptions()
assert(scroll:GetHeight() == 100 and panel:GetHeight() == 44 + 100 + 16)
assert(scroll.scrollChild:GetHeight() == expanded - 44 - 16 + 32 + 38)
panel.top = nil
for _, frame in ipairs(frames) do
    if frame.option and (frame.option.key == "title" or frame.option.key == "inside") then
        frame.option.hidden = true
    end
end
core:RefreshEditModeOptions()
assert(panel:GetHeight() == expanded)
custom:SetHeight(80)
assert(panel:GetHeight() == expanded + 30, "Custom height changes must resize the panel")
button.scripts.OnClick(button)
assert(clicked == 1)
hidden = true
core:RefreshEditModeOptions()
assert(panel:GetHeight() == expanded + 30 - 38, "Hidden rows must not reserve space")
local allocated = #frames
for _ = 1, 5 do
    core:RefreshEditModeOptions()
end
assert(#frames == allocated, "Refresh must reuse frames")
nativeWidth = 180
panel.scripts.OnSizeChanged(panel)
assert(panel.scripts.OnUpdate)
panel.scripts.OnUpdate(panel)
assert(panel:GetHeight() > expanded, "Narrow panels must expand for wrapped labels")
combat = true
core:RefreshEditModeOptions()
assert(not toggle.enabled)
toggle:SetChecked(true)
toggle.scripts.OnClick(toggle)
assert(not value)
combat = false
enabled = false
core:RefreshEditModeOptions()
assert(not toggle.parent:IsShown())
assert(not heading:IsShown(), "Empty Frames section must hide its heading")
assert(panel:IsShown(), "Custom options must work without frame controls")
otherEnabled = false
core:RefreshEditModeOptions()
assert(not panel:IsShown(), "Empty companion panel must hide")
editing = false
callbacks.exit()
assert(not panel:IsShown() and panel.scripts.OnUpdate == nil)
button.scripts.OnClick(button)
assert(clicked == 1, "Stale callbacks must not run outside Edit Mode")
print("PASS: shared Edit Mode border, anchoring, groups, callbacks, dynamic height/wrapping, reuse and combat guards")
