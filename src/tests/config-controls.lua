-- Native row behavior and declaration compatibility without a WoW client.
unpack = unpack or table.unpack
local changes = 0
local libs = {
    ["AceLocale-3.0"] = {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    },
    ["AceConfigRegistry-3.0"] = {
        NotifyChange = function()
            changes = changes + 1
        end,
    },
}
function LibStub(name)
    return assert(libs[name], "Unexpected UI library: " .. name)
end
function Mixin(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
end
StaticPopupDialogs, ACCEPT, CANCEL = {}, "Accept", "Cancel"
local pending
function StaticPopup_Show(_, _, _, callback)
    pending = callback
end
local methods = {}
local function frame()
    return setmetatable({ scripts = {}, height = 32, shown = true }, { __index = methods })
end
function methods:GetHighlightTexture()
    self.highlight = self.highlight or frame()
    return self.highlight
end
function methods:SetFrameStrata(value)
    self.strata = value
end
function methods:SetHighlightAtlas() end
function methods:SetAlpha() end
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
for _, key in ipairs({
    "SetPoint",
    "ClearAllPoints",
    "SetWidth",
    "SetSize",
    "SetJustifyH",
    "SetWordWrap",
    "EnableMouse",
    "SetAllPoints",
    "SetColorTexture",
    "SetTextColor",
    "SetNormalAtlas",
    "SetPushedAtlas",
    "SetAtlas",
    "SetAutoFocus",
    "SetMaxLetters",
    "SetFontObject",
    "SetColorRGB",
}) do
    methods[key] = function() end
end
function methods:CreateFontString()
    return frame()
end
function methods:SetPoint(...)
    self.points = self.points or {}
    local point = { ... }
    self.points[point[1]] = point
end
function methods:ClearAllPoints()
    self.points = {}
end
function methods:SetWidth(value)
    self.width = value
end
function methods:CreateTexture()
    return frame()
end
function methods:GetStringHeight()
    if self.width and self.text then
        return 14 * math.max(1, math.ceil(#self.text * 7 / self.width))
    end
    return 14
end
function methods:GetStringWidth()
    return 60
end
function methods:SetVertexColor(...)
    self.vertexColor = { ... }
end
function methods:SetText(value)
    self.text = value
end
function methods:GetText()
    return self.text
end
function methods:SetHeight(value)
    self.height = value
end
function methods:GetHeight()
    return self.height
end
function methods:GetWidth()
    return 627
end
function methods:SetEnabled(value)
    self.enabled = value
end
function methods:SetChecked(value)
    self.checked = value
end
function methods:GetChecked()
    return self.checked
end
function methods:SetCheckedTexture()
    self.checkedTexture = frame()
end
function methods:GetCheckedTexture()
    return self.checkedTexture
end
function methods:SetDisabledCheckedTexture()
    self.disabledTexture = frame()
end
function methods:GetDisabledCheckedTexture()
    return self.disabledTexture
end
function methods:Hide()
    self.shown = false
end
function methods:Show()
    self.shown = true
end
function methods:IsShown()
    return self.shown
end
function methods:IsVisible()
    return self.shown ~= false and (not self.parent or self.parent:IsVisible())
end
function methods:GetFrameLevel()
    return self.level or 1
end
function methods:SetFrameLevel(value)
    self.level = value
end
function methods:GetEffectiveScale()
    return 1
end
function methods:GetTop()
    return self.top or 100
end
function methods:GetBottom()
    return self.bottom or 0
end
function methods:SetShown(value)
    self.shown = value
end
function methods:HasFocus()
    return self.focused
end
function methods:ClearFocus()
    self.focused = false
    if self.scripts.OnEditFocusLost then
        self.scripts.OnEditFocusLost()
    end
end
function methods:SetupMenu(callback)
    self.menu = callback
end
function methods:GenerateMenu()
    local entries = {}
    local root = {}
    function root:SetScrollMode(height)
        self.maxHeight = height
    end
    function root:CreateRadio(text, selected, choose)
        entries[#entries + 1] = { selected = selected, choose = choose }
    end
    self.menu(self, root)
    self.menuHeight = root.maxHeight
    self.entries, self.selectedIndex = entries, nil
    for index, entry in ipairs(entries) do
        if entry.selected() then
            self.selectedIndex = index
        end
    end
    local index = self.selectedIndex
    self.callback(self.owner, index and entries[index - 1], index and entries[index + 1])
end
function methods:Increment()
    local entry = self.selectedIndex and self.entries[self.selectedIndex + 1]
    if entry then
        entry.choose()
        self:GenerateMenu()
    end
end
function methods:Decrement()
    local entry = self.selectedIndex and self.entries[self.selectedIndex - 1]
    if entry then
        entry.choose()
        self:GenerateMenu()
    end
end
function methods:SetDefaultText(value)
    self.selection = value
end
function methods:RegisterCallback(_, callback, owner)
    self.callback, self.owner = callback, owner
end
function methods:Init(value)
    self.value = value
    self.callback(self.owner, value)
end
function CreateFrame(_, _, parent, template)
    assert(template ~= "SimpleGroup")
    local object = frame()
    object.parent, object.template = parent, template
    if template == "MinimalSliderWithSteppersTemplate" then
        object.RightText = frame()
    end
    if template == "NewFeatureLabelTemplate" then
        object.Label, object.BGLabel, object.Glow = frame(), frame(), frame()
    end
    return object
end
DropdownButtonMixin = { Event = { OnUpdate = "updated" } }
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "changed" }, Label = { Right = 1 } }
GameTooltip = {
    SetOwner = function(self, owner, anchor)
        self.owner, self.anchor = owner, anchor
    end,
    ClearAllPoints = function() end,
    SetPoint = function(self, ...)
        self.point = { ... }
    end,
    SetText = function(self, title)
        self.title, self.lines = title, {}
    end,
    AddLine = function(self, line)
        self.lines[#self.lines + 1] = line
    end,
    Show = function() end,
    Hide = function() end,
}
local app = {
    addon = {},
    config = {
        optionInfo = {
            Test = function(path)
                local defaults = { enabled = false, amount = 3, choice = "a", input = "" }
                return defaults[path[#path]], path[#path] == "amount"
            end,
        },
    },
}
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", app)
app.config.frame = frame()
function app.config:GetOptionTags(option)
    return option
end
function methods:SetScale(value)
    self.scale = value
end
function methods:SetTextToFit(value)
    self.text = value
end
assert(loadfile("Seamless/src/config/badges.lua"))("Seamless", app)
app.config.NotifyChange = function(_, name)
    LibStub("AceConfigRegistry-3.0"):NotifyChange(name)
end
assert(loadfile("Seamless/src/config/controls.lua"))("Seamless", app)
local profile = { enabled = true, amount = 5, choice = "b", input = "old" }
local root = {
    args = {
        general = {
            type = "group",
            name = "General",
            get = function(info)
                assert(info[0] == "Test" and info[1] == "general" and info.type == info.option.type)
                assert(info.uiName == "SeamlessConfig-1.0")
                return profile[info[#info]]
            end,
            set = function(info, value)
                profile[info[#info]] = value
            end,
            args = {
                heading = { type = "group", name = "Feature", order = 0, args = {} },
                enabled = { type = "toggle", name = "Enabled", order = 1 },
                amount = {
                    type = "range",
                    name = "Amount",
                    order = 2,
                    min = 0,
                    max = 10,
                    step = 1,
                    disabled = function()
                        return not profile.enabled
                    end,
                },
                choice = {
                    type = "select",
                    name = "Choice",
                    order = 3,
                    values = { a = "A", b = "B" },
                    sorting = { "b", "a" },
                },
                input = {
                    type = "input",
                    name = "Input",
                    order = 4,
                    validate = function(_, value)
                        return value ~= "bad" or "Invalid"
                    end,
                },
                delete = {
                    type = "execute",
                    name = "Delete",
                    order = 5,
                    confirm = true,
                    func = function()
                        profile.deleted = true
                    end,
                },
                hidden = { type = "toggle", name = "Missing", hidden = true },
            },
        },
    },
}
local page = frame()
app.config:CreateOptionsPage(page, root, "general", "Test")
app.config:RefreshOptionsPage(page)
assert(changes == 0) -- Slider synchronization must never write settings.
assert(page.controlPools.toggle[1].Control:GetChecked())
assert(page.controlPools.select[1].Control.selection == "B")
local slider = page.controlPools.range[1]
slider.Control.callback(slider.Control.owner, 7)
assert(profile.amount == 7 and changes == 1)
local toggle = page.controlPools.toggle[1]
local labelLeft, labelRight = toggle.Label.points.LEFT, toggle.Label.points.RIGHT
local labelWidth, rowHeight, controlLeft = toggle.Label.width, toggle:GetHeight(), toggle.Control.points.LEFT
root.args.general.args.enabled.new = true
app.config:RefreshOptionsPage(page)
assert(toggle.featureTags.new:IsShown())
assert(toggle.featureTags.new.template == "NewFeatureLabelTemplate")
assert(toggle.featureTags.new.scale == 0.8)
assert(toggle.featureTags.new.strata == "HIGH" and toggle.featureTags.new.level == 100)
local tagPoint = toggle.featureTags.new.points.BOTTOMRIGHT
assert(tagPoint[1] == "BOTTOMRIGHT" and tagPoint[2] == toggle.Label)
assert(tagPoint[3] == "LEFT" and tagPoint[4] == 16 and tagPoint[5] == -10)
assert(toggle.featureTags.new.parent == toggle)
page:Hide()
assert(not toggle.featureTags.new:IsVisible(), "tags inherit page visibility")
page:Show()
assert(toggle.featureTags.new:IsVisible())
root.args.general.args.enabled.new = false
root.args.general.args.enabled.blizzard = true
app.config:RefreshOptionsPage(page)
assert(not toggle.featureTags.new:IsShown() and toggle.featureTags.blizzard:IsShown())
assert(toggle.featureTags.blizzard.Label.text == "BLIZZ" and toggle.featureTags.blizzard.BGLabel.text == "BLIZZ")
root.args.general.args.enabled.new = true
app.config:RefreshOptionsPage(page)
assert(toggle.featureTags.new:IsShown() and toggle.featureTags.blizzard:IsShown())
assert(toggle.Label.points.LEFT == labelLeft and toggle.Label.points.RIGHT == labelRight)
assert(toggle.Label.width == labelWidth and toggle:GetHeight() == rowHeight)
assert(toggle.Control.points.LEFT == controlLeft)
assert(toggle.featureTags.new.ignoreInLayout and toggle.featureTags.blizzard.ignoreInLayout)
root.args.general.args.enabled.new, root.args.general.args.enabled.blizzard = nil, nil
app.config:RefreshOptionsPage(page)
assert(not toggle.featureTags.new:IsShown() and not toggle.featureTags.blizzard:IsShown())
-- Layout storage supplies tooltip text without adding a visual tag.
root.args.general.layoutStored = true
app.config:RefreshOptionsPage(page)
toggle.scripts.OnEnter()
assert(GameTooltip.lines[#GameTooltip.lines] == "|cff8080ff[Saved in the Edit Mode layout]|r")
assert(not toggle.featureTags.editMode and not toggle.featureTags.blizzard:IsShown())
root.args.general.layoutStored = nil
-- EDIT MODE marks settings stored in the Edit Mode layout: nearest the label, a blue glow,
-- and a tooltip line on the setting and on every setting inside a tagged group.
root.args.general.args.enabled.editMode, root.args.general.args.enabled.new = true, true
app.config:RefreshOptionsPage(page)
local editTag = toggle.featureTags.editMode
assert(editTag:IsShown() and editTag.Label.text == "EDIT MODE" and editTag.BGLabel.text == "EDIT MODE")
assert(editTag.Glow.vertexColor and editTag.Glow.vertexColor[3] == 1)
assert(editTag.points.BOTTOMRIGHT[2] == toggle.Label)
assert(toggle.featureTags.new.points.RIGHT[2] == editTag.Label)
toggle.scripts.OnEnter()
assert(GameTooltip.lines[#GameTooltip.lines] == "|cff8080ff[Saved in the Edit Mode layout]|r")
root.args.general.args.enabled.editMode, root.args.general.args.enabled.new = nil, nil
root.args.general.args.heading.editMode = true
app.config:RefreshOptionsPage(page)
assert(not editTag:IsShown())
local heading = page.controlPools.group[1]
local headingTag = heading.featureTags.editMode
assert(headingTag:IsShown() and headingTag.points.LEFT[2] == heading.Label)
assert(headingTag.points.LEFT[3] == "LEFT" and headingTag.points.LEFT[4] == (60 + 8) / 0.8)
assert(headingTag.Label.points.LEFT, "heading tags extend right of the heading text")
toggle.scripts.OnEnter()
assert(GameTooltip.lines[#GameTooltip.lines] ~= "|cff8080ff[Saved in the Edit Mode layout]|r")
root.args.general.args.heading.editMode = nil
app.config:RefreshOptionsPage(page)
assert(not headingTag:IsShown())
toggle.scripts.OnEnter()
assert(GameTooltip.owner == toggle and GameTooltip.anchor == "ANCHOR_NONE")
assert(GameTooltip.point[1] == "BOTTOMLEFT" and GameTooltip.point[2] == toggle.Label)
assert(GameTooltip.point[3] == "TOPRIGHT" and GameTooltip.point[4] == 12 and GameTooltip.point[5] == 8)
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ffDisabled|r)")
toggle.Control.scripts.OnEnter()
assert(GameTooltip.point[2] == toggle.Label and GameTooltip.owner == toggle)
slider.scripts.OnEnter()
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ff3|r)")
assert(GameTooltip.lines[2] == "|cff8080ff[Per-character setting]|r")
page.controlPools.select[1].scripts.OnEnter()
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ffA|r)")
-- An option's own default (a value only the game knows) wins over the resolver,
-- keeps the resolver's per-character flag and still shows choice labels.
root.args.general.args.amount.default = function()
    return 6
end
slider.scripts.OnEnter()
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ff6|r)")
assert(GameTooltip.lines[2] == "|cff8080ff[Per-character setting]|r")
root.args.general.args.amount.default = nil
root.args.general.args.choice.default = "b"
page.controlPools.select[1].scripts.OnEnter()
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ffB|r)")
root.args.general.args.choice.default = nil
-- CVar metadata comes from both page resolvers and option-local default lookups.
local resolver = app.config.optionInfo.Test
app.config.optionInfo.Test = function(path)
    local value, character = resolver(path)
    return value, character, true
end
toggle.scripts.OnEnter()
assert(GameTooltip.lines[2] == "|cff8080ff[Blizzard CVAR]|r")
app.config.optionInfo.Test = resolver
C_CVar = {
    GetCVarInfo = function()
        return "1", "0", false, true
    end,
}
root.args.general.args.enabled.default = function()
    return app.addon:GetCVarOptionInfo("testCVar")
end
toggle.scripts.OnEnter()
assert(GameTooltip.lines[1] == "\n(Default: |cff8080ffDisabled|r)")
assert(GameTooltip.lines[2] == "|cff8080ff[Per-character setting]|r")
assert(GameTooltip.lines[3] == "|cff8080ff[Blizzard CVAR]|r")
root.args.general.args.enabled.default = nil
-- The label and empty row space share the checkbox's guarded commit path.
toggle.scripts.OnMouseUp(toggle, "RightButton")
assert(profile.enabled, "Right-clicking a checkbox row must not toggle it")
local enabledOption = root.args.general.args.enabled
enabledOption.disabled = true
app.config:RefreshOptionsPage(page)
toggle.scripts.OnMouseUp(toggle, "LeftButton")
assert(profile.enabled, "Disabled checkbox rows must not toggle")
enabledOption.disabled = nil
enabledOption.validate = function()
    return false
end
app.config:RefreshOptionsPage(page)
toggle.scripts.OnMouseUp(toggle, "LeftButton")
assert(profile.enabled, "Row clicks must honor validation")
enabledOption.validate = nil
enabledOption.confirm = true
toggle.scripts.OnMouseUp(toggle, "LeftButton")
assert(profile.enabled and pending, "Row clicks must honor confirmation")
pending()
pending = nil
enabledOption.confirm = nil
app.config:RefreshOptionsPage(page)
assert(not profile.enabled and not slider.Control.enabled)
toggle.scripts.OnMouseUp(toggle, "LeftButton")
app.config:RefreshOptionsPage(page)
assert(profile.enabled and toggle.Control:GetChecked(), "Row clicks must also enable a checkbox")
toggle.Control:SetChecked(false)
toggle.Control.scripts.OnClick()
app.config:RefreshOptionsPage(page)
assert(not profile.enabled and not toggle.Control:GetChecked(), "Direct checkbox clicks must still work")
slider:Commit(9)
assert(profile.amount == 7)
local input = page.controlPools.input[1]
input:Commit("bad")
assert(profile.input == "old")
input:Commit("new")
assert(profile.input == "new")
local delete = page.controlPools.execute[1]
delete:Commit()
assert(not profile.deleted and pending)
pending()
assert(profile.deleted)
-- The same pooled controls read the replacement profile, never a cached table.
profile = { enabled = true, amount = 2, choice = "a", input = "other" }
app.config:RefreshOptionsPage(page)
assert(page.controlPools.range[1] == slider and slider.Control.value == 2)
assert(page.controlPools.input[1].Control:GetText() == "other")
-- Dynamic nested groups are resolved against the current declaration tree.
root.args.general.args.extra = { type = "description", name = "Added", order = 10 }
app.config:RefreshOptionsPage(page)
assert(page.controlPools.description.used == 1)
root.args.general.args.extra = nil
app.config:RefreshOptionsPage(page)
assert(not page.controlPools.description[1]:IsShown())
root.args.general.args.section = {
    type = "group",
    name = "Section",
    order = 20,
    args = { nested = { type = "description", name = "Nested" } },
}
app.config:RefreshOptionsPage(page)
local section = page.controlPools.group[2]
section.HeaderButton.scripts.OnEnter()
assert(section.Hover:IsShown())
section.HeaderButton.scripts.OnLeave()
assert(not section.Hover:IsShown())
section.Toggle.scripts.OnEnter()
assert(section.Hover:IsShown())
section.Toggle.scripts.OnLeave()
assert(not section.Hover:IsShown())
local expandedHeight = page:GetHeight()
assert(page.controlPools.description[1]:IsShown())
section.Toggle.scripts.OnClick()
assert(section.collapsed and page:GetHeight() < expandedHeight)
assert(not page.controlPools.description[1]:IsShown())
app.config:RefreshOptionsPage(page)
assert(section.collapsed) -- Changes and profile refreshes retain the section state.
section.HeaderButton.scripts.OnClick()
assert(not section.collapsed and page:GetHeight() == expandedHeight)
assert(page.controlPools.description[1]:IsShown())
local color = { 0.1, 0.2, 0.3, 0.4 }
root.args.general.args.color = {
    type = "color",
    name = "Color",
    hasAlpha = true,
    get = function()
        return unpack(color)
    end,
    set = function(_, ...)
        color = { ... }
    end,
}
local pickerInfo
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info)
        pickerInfo = info
    end,
    GetColorRGB = function()
        return 0.5, 0.6, 0.7
    end,
    GetColorAlpha = function()
        return 0.8
    end,
}
app.config:RefreshOptionsPage(page)
page.controlPools.color[1].Control.scripts.OnClick()
assert(pickerInfo.hasOpacity and pickerInfo.opacity == 0.4)
pickerInfo.swatchFunc()
assert(color[1] == 0.5 and color[4] == 0.8)
pickerInfo.cancelFunc()
assert(color[1] == 0.1 and color[4] == 0.4)
-- AceDBOptions uses handler method names rather than function values.
local handler = {}
handler.Get = function(self, info)
    assert(info.handler == self)
    return "current"
end
root.args.profiles = { type = "group", handler = handler, args = { choose = { type = "select", get = "Get" } } }
assert(app.config.Option:New(root, { "profiles", "choose" }, "Test"):Read("get") == "current")
local select = page.controlPools.select[1]
app.config:RefreshOptionsPage(page)
assert(select.Previous.template == "SteppersDecrementButtonTemplate")
assert(select.Next.template == "SteppersIncrementButtonTemplate")
assert(select.Previous.enabled and not select.Next.enabled)
select.Previous.scripts.OnClick()
assert(profile.choice == "b")
assert(not select.Previous.enabled and select.Next.enabled)
select.Next.scripts.OnClick()
assert(profile.choice == "a")
select.Next.scripts.OnClick()
assert(profile.choice == "a", "steppers must not wrap")
root.args.general.args.choice.disabled = true
app.config:RefreshOptionsPage(page)
assert(not select.Previous.enabled and not select.Next.enabled)
root.args.general.args.choice.disabled = false
root.args.general.args.choice.values = { a = "A" }
root.args.general.args.choice.sorting = { "a" }
app.config:RefreshOptionsPage(page)
assert(not select.Previous.enabled and not select.Next.enabled)
-- Native scroll mode bounds long menus without changing the choice order.
assert(select.Control.menuHeight == 160)
local choice = root.args.general.args.choice
choice.values, choice.sorting = {}, {}
for i = 1, 40 do
    choice.values[i], choice.sorting[i] = "Choice " .. i, i
end
profile.choice = 1
app.config:RefreshOptionsPage(page)
assert(#select.Control.entries == 40 and select.Control.menuHeight == 160)
select.Next.scripts.OnClick()
assert(profile.choice == 2)
-- A slider's numeric field shares the same setter, validation and confirmation.
local range = page.controlPools.range[1]
local edit = range.ValueInput
assert(edit.template == "InputBoxTemplate" and not range.Control.RightText:IsShown())
assert(edit:GetText() == tostring(profile.amount))
local function enter(text)
    edit.focused = true
    edit:SetText(text)
    edit.scripts.OnEnterPressed()
end
for _, text in ipairs({ "", "abc", "-1", "11", "1e999", "nan" }) do
    local before = profile.amount
    enter(text)
    assert(profile.amount == before and GameTooltip.title == "Invalid value")
    assert(edit:HasFocus(), "invalid input stays editable")
end
enter("6")
assert(profile.amount == 6 and edit:GetText() == "6" and not edit:HasFocus())
enter("6.6")
assert(profile.amount == 7 and edit:GetText() == "7", "respect integer steps")
local amount = root.args.general.args.amount
amount.min, amount.max, amount.step = -10, 10, 0.1
app.config:RefreshOptionsPage(page)
enter("-2.34")
assert(profile.amount == -2.3 and edit:GetText() == "-2.3", "accept negatives and snap decimal steps")
amount.validate = function(_, value)
    return value ~= 4
end
enter("4")
assert(profile.amount == -2.3 and edit:HasFocus(), "custom validators still apply")
amount.validate = nil
amount.confirm = true
enter("3")
assert(profile.amount == -2.3 and pending, "typing still requires configured confirmation")
pending()
assert(profile.amount == 3)
amount.confirm = nil
app.config:RefreshOptionsPage(page)
edit.focused = true
edit:SetText("9")
edit.scripts.OnEscapePressed()
assert(profile.amount == 3 and edit:GetText() == "3")
edit.focused = true
edit:SetText("9")
edit:ClearFocus()
assert(profile.amount == 3 and edit:GetText() == "3", "focus loss discards unfinished input")
amount.disabled = true
enter("8")
assert(profile.amount == 3, "recheck disabled state at commit")
app.config:RefreshOptionsPage(page)
assert(not edit.enabled)
amount.disabled = nil
app.config:RefreshOptionsPage(page)
edit.focused = true
edit:SetText("9")
profile = { enabled = true, amount = 1.5, choice = 2, input = "new profile" }
app.config:RefreshOptionsPage(page)
assert(edit:GetText() == "1.5" and not edit:HasFocus(), "refresh discards stale profile input")
range.Control.callback(range.Control.owner, 2.5)
assert(profile.amount == 2.5 and edit:GetText() == "2.5", "dragging updates the numeric field")
amount.min, amount.max, amount.step = 0.5, 3, 0.01
profile.amount = 2.6099998951
app.config:RefreshOptionsPage(page)
assert(edit:GetText() == "2.61" and profile.amount == 2.6099998951, "refresh formats existing noise without saving")
range.Control.callback(range.Control.owner, 2.6099998951)
assert(profile.amount == 2.61 and edit:GetText() == "2.61", "dragging snaps noisy values to the declared step")
enter("2.606")
assert(profile.amount == 2.61 and edit:GetText() == "2.61", "typing and dragging use the same steps")
amount.min, amount.max, amount.step = 0.05, 3.05, 0.1
range.Control.callback(range.Control.owner, 2.24999999)
assert(profile.amount == 2.25 and edit:GetText() == "2.25", "fractional minimum offsets retain their precision")
amount.min, amount.max, amount.step = 0, 10, 1
range.Control.callback(range.Control.owner, 6.9999999)
assert(profile.amount == 7 and edit:GetText() == "7", "integer sliders have no decimal noise")
-- A fresh page measures long names before its rows have screen anchors. Clicking must not
-- change the label column or reveal a second line that was clipped on the first display.
root.args.general.args.enabled.name = "Pass unused Edit Mode keys through"
local wrappedPage = frame()
app.config:CreateOptionsPage(wrappedPage, root, "general", "Test")
app.config:RefreshOptionsPage(wrappedPage)
local wrapped = wrappedPage.controlPools.toggle[1]
local wrappedWidth, wrappedHeight = wrapped.Label.width, wrapped:GetHeight()
assert(wrappedWidth == 627 / 2 - 85 - 37, "Label width must be explicit before measuring wrapped text")
assert(wrappedHeight == 40, "Long option names need space for two lines on first display")
wrapped.scripts.OnMouseUp(wrapped, "LeftButton")
app.config:RefreshOptionsPage(wrappedPage)
assert(wrapped.Label.width == wrappedWidth and wrapped:GetHeight() == wrappedHeight)
root.args.general.args.enabled.name = "Enabled"
app.config:RefreshOptionsPage(wrappedPage)
assert(wrapped:GetHeight() == 32, "Pooled rows must shrink again for short names")
print("Native config controls OK")
