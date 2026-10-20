---@type string, SeamlessCore
local _, app = ...

-- Suite-only additions to the namespaced LibEditMode instance. The vendored files stay
-- untouched; this relies on lib.internal, so recheck it whenever the library is updated.
local lib = app.LibEditMode
local internal = lib.internal
assert(lib.SettingType.Header == nil, "LibEditMode now defines Header; review editmodelib.lua")
assert(type(internal.CreatePool) == "function" and type(internal.CreateDialog) == "function")

-- Section title, styled like Blizzard's Edit Mode category titles (GameFontNormalLarge, 32 high).
lib.SettingType.Header = "seamless-header"

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
end

internal:CreatePool(lib.SettingType.Header, function()
    local frame = Mixin(CreateFrame("Frame", nil, UIParent), headerMixin)
    frame:SetSize(330, 32)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("LEFT")
    label:SetJustifyH("LEFT")
    frame.Label = label
    return frame
end, function(_, frame)
    frame:Hide()
    frame.Label:SetText()
    frame.layoutIndex = nil
end)

-- Share of the screen height the settings list may use before it scrolls.
local MAX_HEIGHT_SHARE = 0.6

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

    local update = dialog.Update
    function dialog:Update(selection)
        if selection ~= self.selection then
            scroll:SetVerticalScroll(0)
        end
        scroll.maximumHeight = math.floor(UIParent:GetHeight() * MAX_HEIGHT_SHARE)
        update(self, selection)
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
