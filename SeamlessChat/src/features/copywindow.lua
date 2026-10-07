-- The copy window (copywindow.xml): chat lines in a scrolling edit box, all of them selected when it
-- opens, so Ctrl+C copies them right away. Opened by the copy button in each chat window (copy.lua).

---@class SeamlessChatCopyWindowMixin : Frame
---@field ScrollingEditBox Frame ScrollingEditBoxTemplate
---@field ScrollBar EventFrame MinimalScrollBar
SeamlessChatCopyWindowMixin = {}

function SeamlessChatCopyWindowMixin:OnLoad()
    self:SetTitle("Copy chat")
    self:RegisterForDrag("LeftButton")
    ScrollUtil.RegisterScrollBoxWithScrollBar(self.ScrollingEditBox:GetScrollBox(), self.ScrollBar)
    self.ScrollingEditBox:GetEditBox():SetMaxLetters(0)
    -- Escape closes the window, also while the text has focus.
    self.ScrollingEditBox:RegisterCallback("OnEscapePressed", function()
        self:Hide()
    end, self)
    tinsert(UISpecialFrames, self:GetName())
end

function SeamlessChatCopyWindowMixin:OnDragStart()
    self:StartMoving()
end

function SeamlessChatCopyWindowMixin:OnDragStop()
    self:StopMovingOrSizing()
end

function SeamlessChatCopyWindowMixin:OnHide()
    self.ScrollingEditBox:SetText("")
end

-- Shows `text` scrolled to its end (the newest lines), selected and focused.
---@param text string
---@param title string? "Copy chat" when nil
function SeamlessChatCopyWindowMixin:ShowText(text, title)
    self:SetTitle(title or "Copy chat")
    self:Show()
    self.ScrollingEditBox:SetText(text)
    local editBox = self.ScrollingEditBox:GetEditBox()
    editBox:SetFocus()
    editBox:SetCursorPosition(#text)
    editBox:HighlightText()
    -- The text is laid out on the next frame; only then is its end known.
    local scrollBox = self.ScrollingEditBox:GetScrollBox()
    C_Timer.After(0, function()
        scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
    end)
end
