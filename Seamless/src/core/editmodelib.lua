---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance. The vendored files stay
-- untouched; this relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(type(internal.CreatePool) == "function" and type(internal.CreateDialog) == "function")

local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local HIGHLIGHT = "Interface\\Buttons\\UI-PlusButton-Hilight"

-- Collapsed sections are remembered account-wide, by section key.
local collapsedFallback = {}
local function CollapsedSections()
    if not app.db then
        return collapsedFallback
    end
    app.db.global.editModeCollapsed = app.db.global.editModeCollapsed or {}
    return app.db.global.editModeCollapsed
end

---@param key string
---@return boolean
function app.IsEditModeSectionCollapsed(key)
    return CollapsedSections()[key] == true
end

---@param key string
---@param collapsed boolean
function app.SetEditModeSectionCollapsed(key, collapsed)
    CollapsedSections()[key] = collapsed or nil
end

---Style a collapsible section header like Blizzard's quest-log headers: a +/- button and a gold title.
---@param frame table
---@return table button
function app.CreateEditModeHeaderButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(16, 16)
    button:SetPoint("LEFT")
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button:SetScript("OnClick", function()
        frame:Toggle()
    end)
    frame.Toggle = frame.Toggle or function() end
    frame.CollapseButton = button
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function()
        frame:Toggle()
    end)
    return button
end

---@param button table
---@param collapsed boolean
function app.SetEditModeHeaderCollapsed(button, collapsed)
    local texture = collapsed and PLUS or MINUS
    button:SetNormalTexture(texture)
    button:SetPushedTexture(texture)
end

-- Collapsible section title, styled like Blizzard's Edit Mode category titles (GameFontNormalLarge,
-- 32 high). Rows after it, up to the next header, hide while it is collapsed.
lib.SettingType.Header = "seamless-header"

local function HeaderKey(data)
    return "settings:" .. (data.key or data.name)
end

local headerMixin = {}
function headerMixin:Setup(data)
    self.setting = data
    self.Label:SetText(data.name)
    self:Refresh()
end

function headerMixin:Refresh()
    local data = self.setting
    if type(data.hidden) == "function" then
        self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
    else
        self:SetShown(not data.hidden)
    end
    app.SetEditModeHeaderCollapsed(self.CollapseButton, self:IsCollapsed())
end

function headerMixin:IsCollapsed()
    return app.IsEditModeSectionCollapsed(HeaderKey(self.setting))
end

function headerMixin:Toggle()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    app.SetEditModeSectionCollapsed(HeaderKey(self.setting), not self:IsCollapsed())
    self:GetParent():GetParent():RefreshWidgets()
end

internal:CreatePool(lib.SettingType.Header, function()
    local frame = Mixin(CreateFrame("Frame", nil, UIParent), headerMixin)
    frame:SetSize(330, 32)
    app.CreateEditModeHeaderButton(frame)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("LEFT", frame.CollapseButton, "RIGHT", 4, 0)
    label:SetJustifyH("LEFT")
    frame.Label = label
    return frame
end, function(_, frame)
    frame:Hide()
    frame.Label:SetText()
    frame.layoutIndex = nil
end)

-- The settings list scrolls past this height, like Blizzard's own settings container (325).
local MAX_HEIGHT, MAX_HEIGHT_SHARE = 400, 0.6

-- Hide every row after a collapsed header, up to the next header.
local function ApplyCollapsed(dialog)
    local collapsed = false
    for _, widget in ipairs(dialog.Settings.widgets) do
        if widget.setting and widget.setting.kind == lib.SettingType.Header then
            collapsed = widget:IsShown() and widget:IsCollapsed()
        elseif collapsed then
            widget:Hide()
        end
    end
end

-- Put the selected frame's settings list in a scroll frame, built like Blizzard's own
-- Edit Mode settings container (ResizeLayoutFrame + ScrollFrameTemplate with a maximum height).
local function AddScrolling(dialog)
    local settings = dialog.Settings
    local scroll = CreateFrame("ScrollFrame", nil, dialog, "ResizeLayoutFrame, ScrollFrameTemplate")
    scroll:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -12)
    scroll.ScrollBar.ignoreInLayout = true
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    -- Widgets refresh through their grandparent, which is the scroll frame now.
    function scroll:RefreshWidgets()
        dialog:RefreshWidgets()
    end
    settings:ClearAllPoints()
    settings:SetParent(scroll)
    scroll:SetScrollChild(settings)
    dialog.Buttons:ClearAllPoints()
    dialog.Buttons:SetPoint("TOP", scroll, "BOTTOM", 0, -12)
    dialog.SettingsScroll = scroll

    local update, refreshWidgets = dialog.Update, dialog.RefreshWidgets
    function dialog:Update(selection)
        if selection ~= self.selection then
            scroll:SetVerticalScroll(0)
        end
        scroll.maximumHeight = math.floor(math.min(MAX_HEIGHT, UIParent:GetHeight() * MAX_HEIGHT_SHARE))
        update(self, selection)
        ApplyCollapsed(self)
        self:Layout()
    end
    -- Never hide the dialog here: its OnHide clears the frame selection.
    function dialog:RefreshWidgets()
        refreshWidgets(self)
        ApplyCollapsed(self)
        if self:IsShown() then
            self:Layout()
        end
    end
end

if internal.dialog then
    AddScrolling(internal.dialog)
else
    local createDialog = internal.CreateDialog
    function internal:CreateDialog()
        local dialog = createDialog(self)
        AddScrolling(dialog)
        return dialog
    end
end
