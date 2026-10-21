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
    "SetFontObject",
    "SetColorRGB",
}) do
    methods[key] = function() end
end
function methods:CreateFontString()
    return frame()
end
function methods:CreateTexture()
    return frame()
end
function methods:GetStringHeight()
    return 14
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
function methods:GenerateMenu() end
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
    return object
end
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "changed" }, Label = { Right = 1 } }
GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end, Hide = function() end }
local app = { config = {} }
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", app)
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
toggle:Commit(false)
app.config:RefreshOptionsPage(page)
assert(not profile.enabled and not slider.Control.enabled)
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
print("Native config controls OK")
