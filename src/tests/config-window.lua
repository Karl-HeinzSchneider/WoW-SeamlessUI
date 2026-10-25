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
function methods:GetBottom()
    return self:GetTop() - self:GetHeight()
end
function methods:GetEffectiveScale()
    return 1
end
function methods:IsVisible()
    return self.shown ~= false and (not self.parent or self.parent:IsVisible())
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
    "SetHideIfUnscrollable",
    "DesaturateHierarchy",
    "EnableMouseWheel",
    "SetSelected",
    "SetNormalAtlas",
    "SetCheckedTexture",
    "SetChecked",
    "SetEnabled",
    "SetPushedAtlas",
    "SetHighlightAtlas",
    "SetAlpha",
    "Raise",
}) do
    methods[name] = function() end
end
local toolbarButtons = {}
function CreateFrame(kind, name, parent, template)
    local frame = object()
    if kind == "Button" then
        toolbarButtons[#toolbarButtons + 1] = frame
    end
    frame.parent, frame.template = parent, template
    frame.level = (template == "UIPanelCloseButtonNoScripts" or template == "UIPanelCloseButtonDefaultAnchors") and 510
        or ((parent and parent:GetFrameLevel() or 0) + 1)
    if template == "MinimalTabTemplate" then
        frame.Text = object()
    end
    if template == "NewFeatureLabelTemplate" then
        frame.Label, frame.BGLabel = object(), object()
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
StaticPopupDialogs = {}
function StaticPopup_Hide() end
function methods:SetTexture() end
function methods:SetColorTexture() end
config.frame = nil
C_AddOns = {
    GetAddOnMetadata = function()
        return "|cff8080ff@project-version@|r"
    end,
}
assert(loadfile("Seamless/src/config/window.lua"))("Seamless", app)
function methods:SetTextToFit(value)
    self.text = value
end
assert(loadfile("Seamless/src/config/badges.lua"))("Seamless", app)
local created, refreshedPage = 0, 0
core:RegisterConfigCategory("Page", {
    new = true,
    blizzard = true,
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
local visiblePopup
function StaticPopup_Visible()
    return visiblePopup and "StaticPopup1", visiblePopup
end
function StaticPopup_Show(which, _, _, link)
    assert(which == "SeamlessConfigLinkCopy")
    visiblePopup = { data = link }
end
function StaticPopup_Hide()
    visiblePopup = nil
end
local links = {}
for _, button in ipairs(toolbarButtons) do
    if button.parent == config.toolbar then
        links[#links + 1] = button
    end
end
assert(#links == 3)
links[1].scripts.OnClick()
assert(visiblePopup.data == "https://discord.gg/D7CtUHT87G")
links[2].scripts.OnClick()
assert(visiblePopup.data == "https://github.com/Karl-HeinzSchneider/WoW-SeamlessUI")
links[2].scripts.OnClick()
assert(not visiblePopup)
links[3].scripts.OnClick()
assert(visiblePopup.data == "https://buymeacoffee.com/karlheinzschneider")
config.toolbar.scripts.OnHide()
assert(not visiblePopup)
local editBox = {}
function editBox:SetText(text)
    self.text = text
end
function editBox:HighlightText()
    self.highlighted = true
end
function editBox:SetFocus()
    self.focused = true
end
function editBox:ClearFocus()
    self.focused = false
end
local dialog = {
    GetEditBox = function()
        return editBox
    end,
}
StaticPopupDialogs.SeamlessConfigLinkCopy.OnShow(dialog, "https://example.com")
assert(editBox.text == "https://example.com" and editBox.highlighted and editBox.focused)
StaticPopupDialogs.SeamlessConfigLinkCopy.OnHide(dialog)
assert(editBox.text == "" and not editBox.focused)
assert(config.navigation:GetWidth() == 175)
for _, row in ipairs(config.rows) do
    if row.id == "Page" then
        assert(row.featureTags.new:IsShown() and row.featureTags.blizzard:IsShown())
        assert(row.featureTags.blizzard.Label.text == "BLIZZ")
        assert(row.text.points.LEFT[2] == 24, "tags must not shift category labels")
    end
end
-- An empty, page-high spacer ends the category list.
local lastRow = config.rows[#config:GetVisibleCategories()]
assert(config.listEnd and config.listEnd:GetHeight() == 20)
assert(config.list:GetHeight() == -lastRow.points.TOPLEFT[3] + lastRow:GetHeight() + 1 + 20)
local headerRight, dividerX = 18 + config.navigation:GetWidth(), 18 + 199
local scrollbarCenter = headerRight + config.navigationBar.points.TOP[4]
assert(scrollbarCenter - headerRight == dividerX - scrollbarCenter)
assert(scrollbarCenter - 17 / 2 > headerRight and scrollbarCenter + 17 / 2 < dividerX)
assert(config.navigationBar.points.TOP[1] == "TOP")
assert(config.navigationBar.points.BOTTOM[1] == "BOTTOM")
assert(config.navigationBar.points.TOP[4] == 12 and config.navigationBar.points.TOP[5] == -8)
assert(config.navigationBar.points.BOTTOM[4] == 12 and config.navigationBar.points.BOTTOM[5] == 8)
for _, row in ipairs(config.rows) do
    assert(row:GetWidth() == 175 and row.active:GetWidth() == 175)
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

-- A fitting category list retains its disabled scrollbar, including after restore.
function methods:SetScrollAllowed(value)
    self.scrollAllowed = value
end
function methods:SetAlpha(value)
    self.alpha = value
end
config.navigation:SetHeight(10000)
assert(config.navigationBar:IsShown() and not config.navigationBar.scrollAllowed)
assert(config.navigationBar.alpha == 0.45)
config:SetMinimized(true)
assert(not config.navigationBar:IsShown())
config:SetMinimized(false)
assert(config.navigationBar:IsShown() and config.navigationBar.alpha == 0.45)
config.navigation:SetHeight(100)
assert(config.navigationBar.scrollAllowed and config.navigationBar.alpha == 1)
print("Persistent navigation scrollbar OK")

-- Header callbacks are optional, protected and deferred; queued writes retain their page.
local pending, state, combat, warnings = nil, true, false, 0
C_Timer = {
    After = function(_, callback)
        pending = callback
    end,
}
function InCombatLockdown()
    return combat
end
app.logger = {
    warn = function()
        warnings = warnings + 1
    end,
}
function methods:SetChecked(value)
    self.checked = value
end
function methods:GetChecked()
    return self.checked
end
function methods:SetEnabled(value)
    self.enabled = value
end
assert(not config.editModeVisibility:IsShown())
config.categories.Page.editModeVisibility = function(value)
    if value ~= nil then
        state = value
    end
    return state
end
config:RefreshEditModeVisibility()
local checkbox = config.editModeVisibility
assert(checkbox:IsShown() and checkbox.checked and checkbox.enabled)
checkbox.checked = false
checkbox.scripts.OnClick()
assert(state and pending)
pending()
assert(not state and not checkbox.checked)
combat = true
checkbox.checked = true
checkbox.scripts.OnClick()
pending()
assert(not state and not checkbox.enabled)
combat = false
config.categories.Page.editModeVisibility = function()
    error("callback failed")
end
config:RefreshEditModeVisibility()
assert(warnings == 1 and not checkbox.enabled)
config.categories.Page.editModeVisibility = function()
    return true
end
config:SetMinimized(true)
assert(not checkbox:IsShown())
config:SetMinimized(false)
assert(checkbox:IsShown())
config.categories.Page.editModeVisibility = nil
config:RefreshEditModeVisibility()
assert(not checkbox:IsShown())
print("Optional protected Edit Mode visibility header OK")
