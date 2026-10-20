---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance. The vendored files stay
-- untouched; this relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(type(internal.CreatePool) == "function" and type(internal.CreateDialog) == "function")

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

local function SetCollapsedState(header, collapsed)
    header.StateIcon:SetAtlas(collapsed and "common-button-list-plus" or "common-button-list-minus", true)
end

local function SetHeaderText(header, text)
    header.Name:SetText(text)
end

---Create a collapsible section header that looks like the character frame's reputation headers:
---the collapse/expand bar, a gold name on the left and a +/- icon on the right.
---@param parent table
---@param onClick fun()
---@return table header
function app.CreateEditModeHeader(parent, onClick)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(28)
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-button-list-collapseExpand")
    background:SetAllPoints()
    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("common-button-list-collapseExpand")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)
    highlight:SetAllPoints()
    header.StateIcon = header:CreateTexture(nil, "BORDER")
    header.StateIcon:SetPoint("RIGHT", -8, -1)
    header.Name = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
    header.Name:SetPoint("LEFT", 10, 0)
    header.Name:SetPoint("RIGHT", header.StateIcon, "LEFT", -4, 0)
    header.SetHeaderText = SetHeaderText
    header.UpdateCollapsedState = SetCollapsedState
    header:SetScript("OnMouseDown", function()
        header.Name:AdjustPointsOffset(1, -1)
    end)
    header:SetScript("OnMouseUp", function()
        header.Name:AdjustPointsOffset(-1, 1)
    end)
    header:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    SetCollapsedState(header, false)
    return header
end

-- Collapsible section header. Rows after it, up to the next header, hide while it is collapsed.
lib.SettingType.Header = "seamless-header"

local function HeaderKey(data)
    return "settings:" .. (data.key or data.name)
end

local headerMixin = {}
function headerMixin:Setup(data)
    self.setting = data
    self:SetHeaderText(data.name)
    self:Refresh()
end

function headerMixin:Refresh()
    local data = self.setting
    if type(data.hidden) == "function" then
        self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
    else
        self:SetShown(not data.hidden)
    end
    self:UpdateCollapsedState(self:IsCollapsed())
end

function headerMixin:IsCollapsed()
    return app.IsEditModeSectionCollapsed(HeaderKey(self.setting))
end

function headerMixin:Toggle()
    app.SetEditModeSectionCollapsed(HeaderKey(self.setting), not self:IsCollapsed())
    self:GetParent():GetParent():RefreshWidgets()
end

internal:CreatePool(lib.SettingType.Header, function()
    local frame
    frame = app.CreateEditModeHeader(UIParent, function()
        frame:Toggle()
    end)
    Mixin(frame, headerMixin)
    frame:SetWidth(330)
    return frame
end, function(_, frame)
    frame:Hide()
    frame:SetHeaderText("")
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

-- Space between the window's right edge and its scroll bar, which sits outside the window.
local SCROLL_BAR_GAP = 2

-- Put the selected frame's settings list in a scroll frame, built like Blizzard's own
-- Edit Mode settings container (ResizeLayoutFrame + ScrollFrameTemplate with a maximum height).
local function AddScrolling(dialog)
    local settings = dialog.Settings
    local scroll = CreateFrame("ScrollFrame", nil, dialog, "ResizeLayoutFrame, ScrollFrameTemplate")
    scroll:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -12)
    -- LayoutFrame only applies maximumHeight when a minimum is set as well.
    scroll.minimumHeight = 1
    scroll:EnableMouseWheel(true)
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

    -- Keep the scroll bar outside the window's right edge, so it never takes width from the rows.
    local function PlaceScrollBar()
        local dialogRight, scrollRight = dialog:GetRight(), scroll:GetRight()
        local inset = (dialogRight and scrollRight) and (dialogRight - scrollRight) or dialog.widthPadding / 2
        local bar = scroll.ScrollBar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", inset + SCROLL_BAR_GAP, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", inset + SCROLL_BAR_GAP, 0)
    end

    local function LayoutDialog()
        dialog:Layout()
        PlaceScrollBar()
    end

    local update, refreshWidgets = dialog.Update, dialog.RefreshWidgets
    function dialog:Update(selection)
        if selection ~= self.selection then
            scroll:SetVerticalScroll(0)
        end
        scroll.maximumHeight = math.floor(math.min(MAX_HEIGHT, UIParent:GetHeight() * MAX_HEIGHT_SHARE))
        -- Measure with every section open, then keep that width so collapsing never resizes the window.
        settings.fixedWidth = nil
        update(self, selection)
        settings.fixedWidth = settings:GetWidth()
        ApplyCollapsed(self)
        LayoutDialog()
    end
    -- Never hide the dialog here: its OnHide clears the frame selection.
    function dialog:RefreshWidgets()
        refreshWidgets(self)
        ApplyCollapsed(self)
        if self:IsShown() then
            LayoutDialog()
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
