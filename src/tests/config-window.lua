-- Registry behavior without the WoW client.
local app = { addon = {} }
function LibStub()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    }
end
assert(loadfile("Seamless/src/config/registry.lua"))("Seamless", app)
local core, config = app.addon, app.config
local function rejects(callback)
    assert(not pcall(callback))
end
core:RegisterConfigCategory("Other", { name = "Other", header = true, order = 20 })
core:RegisterConfigCategory("Other:z", { name = "Z", parent = "Other" })
core:RegisterConfigCategory("Other:a", { name = "A", parent = "Other" })
core:RegisterConfigCategory("Other:deep", { name = "Deep", parent = "Other:a" })
local children = config:GetChildren("Other")
assert(children[1].id == "Other:a" and children[2].id == "Other:z")
rejects(function()
    core:RegisterConfigCategory("Other", { name = "Duplicate" })
end)
rejects(function()
    core:RegisterConfigCategory("Bad", { name = "Bad", parent = "Missing" })
end)
rejects(function()
    core:RegisterConfigCategory("Bad", { name = "Bad", create = true })
end)
assert(not config.categories.Bad)
assert(#config:GetVisibleCategories() == 6)
config.collapsed.Other = true
assert(#config:GetVisibleCategories() == 3)
config.collapsed["Other:a"] = true
local refreshed, shown, raised = 0, false, false
function config:CreateWindow()
    self.frame = {
        Show = function()
            shown = true
        end,
        Raise = function()
            raised = true
        end,
    }
end
function config:Refresh()
    refreshed = refreshed + 1
end
core:RefreshConfig()
assert(refreshed == 0) -- Refresh must not create the window.
core:OpenConfig("Other:deep")
assert(config.selected == "Other:deep" and shown and raised)
assert(not config.collapsed.Other and not config.collapsed["Other:a"])
assert(#config:GetVisibleCategories() == 6)
assert(refreshed == 1)
core:RegisterConfigCategory("Later", { name = "Later" })
assert(refreshed == 2) -- Registration after opening updates the tree.
core:RefreshConfig()
assert(refreshed == 3)
rejects(function()
    core:OpenConfig("Missing")
end)
print("Config registry OK")

-- Exercise page ownership/lifecycle and row callbacks with a small frame mock.
local methods = {}
local function object()
    return setmetatable({ scripts = {}, width = 643, height = 1, offset = 0 }, { __index = methods })
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then
            previous(...)
        end
        callback(...)
    end
end
function methods:SetSize(width, height)
    self.width, self.height = width, height
end
function methods:SetWidth(width)
    self.width = width
end
function methods:SetHeight(height)
    local changed = self.height ~= height
    self.height = height
    if changed and self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self)
    end
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:SetVerticalScroll(offset)
    self.offset = offset
    if self.scripts.OnVerticalScroll then
        self.scripts.OnVerticalScroll(self, offset)
    end
end
function methods:GetVerticalScroll()
    return self.offset
end
function methods:SetScrollPercentage(value)
    self.percentage = value
    if self.callback then
        self.callback(self.owner, value)
    end
end
function methods:GetScrollPercentage()
    return self.percentage or 0
end
function methods:RegisterCallback(_, callback, owner)
    self.callback, self.owner = callback, owner
end
function methods:Show()
    self.shown = true
end
function methods:Hide()
    self.shown = false
end
function methods:IsShown()
    return self.shown == true
end
function methods:GetLeft()
    return 100
end
function methods:GetTop()
    return 800
end
function methods:GetHighlightTexture()
    self.highlight = self.highlight or object()
    return self.highlight
end
function methods:SetShown(value)
    self.shown = value
end
function methods:SetText(value)
    self.text = value
end
function methods:GetStringWidth()
    return 50
end
function methods:GetFrameLevel()
    return 1
end
function methods:CreateFontString()
    return object()
end
function methods:CreateTexture()
    return object()
end
for _, name in ipairs({
    "SetPoint",
    "ClearAllPoints",
    "SetAllPoints",
    "SetAtlas",
    "SetJustifyH",
    "SetFontObject",
    "SetHighlightTexture",
    "SetNormalTexture",
    "SetPushedTexture",
    "SetScale",
    "SetFrameStrata",
    "SetToplevel",
    "SetClampedToScreen",
    "SetMovable",
    "EnableMouse",
    "RegisterForDrag",
    "StartMoving",
    "StopMovingOrSizing",
    "SetFrameLevel",
    "SetScrollChild",
    "Init",
    "SetVisibleExtentPercentage",
    "SetScrollAllowed",
    "EnableMouseWheel",
    "SetSelected",
    "SetNormalAtlas",
    "SetPushedAtlas",
    "SetHighlightAtlas",
    "SetAlpha",
    "Raise",
}) do
    methods[name] = function() end
end
function CreateFrame(_, name, parent, template)
    local frame = object()
    frame.parent, frame.template = parent, template
    frame.level = (template == "UIPanelCloseButtonNoScripts" or template == "UIPanelCloseButtonDefaultAnchors") and 510
        or ((parent and parent:GetFrameLevel() or 0) + 1)
    if template == "MinimalTabTemplate" then
        frame.Text = object()
    end
    if name then
        _G[name] = frame
    end
    return frame
end
function methods:GetFrameLevel()
    return self.level or 1
end
function methods:SetFrameLevel(level)
    self.level = level
end
function methods:SetPoint(...)
    self.points = self.points or {}
    local point = { ... }
    self.points[point[1]] = point
end
function methods:ClearAllPoints()
    self.points = {}
end
UIParent = object()
UIParent:SetSize(1920, 1080)
UISpecialFrames = {}
tinsert = table.insert
NineSliceUtil = { ApplyLayoutByName = function() end }
config.frame = nil
assert(loadfile("Seamless/src/config/window.lua"))("Seamless", app)
local created, refreshedPage = 0, 0
core:RegisterConfigCategory("Page", {
    name = "Page",
    create = function(page)
        created = created + 1
        page:SetHeight(1500)
    end,
    refresh = function()
        refreshedPage = refreshedPage + 1
    end,
})
core:OpenConfig("Page")
assert(config.navigation:GetWidth() == 183)
assert(config.navigationBar.points.TOPLEFT[4] == 6 and config.navigationBar.points.TOPLEFT[5] == -8)
assert(config.navigationBar.points.BOTTOMLEFT[4] == 6 and config.navigationBar.points.BOTTOMLEFT[5] == 8)
for _, row in ipairs(config.rows) do
    assert(row:GetWidth() == 183 and row.active:GetWidth() == 183)
end
assert(config.minimize:GetFrameLevel() == 510)
assert(config.minimize.template == "UIPanelCloseButtonNoScripts")
for _, row in ipairs(config.rows) do
    if row.id == "Seamless" then
        assert(row.toggle.points.RIGHT[2] == -6)
        assert(row.text.points.LEFT[2] == 20 and row.text.points.RIGHT[2] == -30)
    end
end
assert(created == 1 and refreshedPage == 1)
assert(config.content:GetHeight() == 1500)
assert(config.pages.Page.parent == config.pageHost)
config.contentScroll.scripts.OnMouseWheel(config.contentScroll, -1)
assert(config.contentScroll:GetVerticalScroll() == 30)
config.contentScroll:SetVerticalScroll(1400)
config.pages.Page:SetHeight(120) -- Collapsing sections must not leave an empty scrolled page.
assert(config.contentScroll:GetVerticalScroll() <= math.max(0, 120 - config.contentScroll:GetHeight()))
config.pages.Page:SetHeight(1500)
config:Select("Seamless:general")
assert(not config.pages.Page.shown and config.contentScroll:GetVerticalScroll() == 0)
core:OpenConfig("Page")
assert(created == 1 and refreshedPage == 2)
assert(#UISpecialFrames == 1)
for _, row in ipairs(config.rows) do
    if row.id == "Other" then
        row.toggle.scripts.OnClick()
        break
    end
end
assert(config.collapsed.Other)
config.frame.scripts.OnHide(config.frame)
print("Config window lifecycle OK")

core:ToggleConfig()
assert(not config.frame:IsShown())
core:ToggleConfig()
assert(config.frame:IsShown())
local selectedPage = config.pages.Page
config.minimize.scripts.OnClick()
assert(config.minimized and config.frame:GetWidth() == 705 and config.frame:GetHeight() == 600)
assert(not config.navigation.shown and not config.navigationBar.shown)
assert(not config.tab.shown and not config.inner.shown and not config.done.shown)
assert(config.selected == "Page" and config.pages.Page == selectedPage and selectedPage.shown)
core:ToggleConfig()
assert(not config.frame:IsShown())
core:ToggleConfig()
assert(config.frame:IsShown() and config.minimized)
config.minimize.scripts.OnClick()
assert(not config.minimized and config.frame:GetWidth() == 920 and config.frame:GetHeight() == 724)
assert(config.navigation.shown and config.tab.shown and config.inner.shown and config.done.shown)
assert(config.pages.Page == selectedPage and created == 1)
print("Config toggle and compact mode OK")
