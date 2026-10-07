---@type string, SeamlessChat
local _, app = ...

-- The chat log window (logwindow.xml): a search box, the groups on the left (All, Whispers, Guild,
-- ..., Channels with one row per channel), and the matching messages on the right, shown like chat:
-- colored by type, senders in class color, links clickable. Opened with /seamlesschat log or
-- /seamlesschat search <text>. The data comes from app.chatLog (log.lua).

-- How many of the newest matches the window shows.
local RESULT_LIMIT = 2000
-- Seconds after the last keystroke before searching.
local SEARCH_DELAY = 0.25
-- New messages arrive in bursts; the window catches up this long after one.
local LIVE_DELAY = 1

-- Group rows --------------------------------------------------------------------------------------

---@class SeamlessChat.LogGroupRow
---@field name string
---@field count integer
---@field group string? a key of app.chatLog.GROUPS; nil for "All messages"
---@field channel string? a channel of the "channel" group

---@class SeamlessChatLogGroupMixin : Button
---@field Label FontString
---@field Count FontString
---@field Selected Texture
---@field row SeamlessChat.LogGroupRow
SeamlessChatLogGroupMixin = {}

---@param row SeamlessChat.LogGroupRow
---@param selected boolean
function SeamlessChatLogGroupMixin:Init(row, selected)
    self.row = row
    -- Channels are indented below "Channels".
    self.Label:SetPoint("LEFT", row.channel and 22 or 8, 0)
    self.Label:SetText(row.name)
    self.Count:SetText(row.count)
    self.Selected:SetShown(selected)
end

function SeamlessChatLogGroupMixin:OnClick()
    SeamlessChatLogWindow:Select(self.row)
end

-- Button beside the chat ---------------------------------------------------------------------------

---@class SeamlessChatLogButtonMixin : Button
---@field Icon Texture
SeamlessChatLogButtonMixin = {}

function SeamlessChatLogButtonMixin:OnClick()
    SeamlessChatLogWindow:Toggle()
end

-- A title-only tooltip, like the chat's other buttons.
function SeamlessChatLogButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Chat log")
    GameTooltip:Show()
end

function SeamlessChatLogButtonMixin:OnLeave()
    GameTooltip:Hide()
end

-- The icon moves with the pushed art, as on the chat's other buttons.
function SeamlessChatLogButtonMixin:OnMouseDown()
    self.Icon:SetPoint("CENTER", -1, -2)
    self.Icon:SetAlpha(0.75)
end

function SeamlessChatLogButtonMixin:OnMouseUp()
    self.Icon:SetPoint("CENTER", 0, 0)
    self.Icon:SetAlpha(1)
end

-- Window -------------------------------------------------------------------------------------------

---@class SeamlessChatLogWindowMixin : Frame
---@field SearchBox EditBox
---@field GroupList Frame WowScrollBoxList
---@field GroupScrollBar EventFrame
---@field Results Frame ScrollingMessageFrame
---@field ResultScrollBar EventFrame
---@field CopyButton Button
---@field Status FontString
---@field selected SeamlessChat.LogGroupRow
---@field matches SeamlessChat.LogRecord[]
---@field updateToken integer
---@field groupsStale boolean
SeamlessChatLogWindowMixin = {}

function SeamlessChatLogWindowMixin:OnLoad()
    self:SetTitle("Chat log")
    self:RegisterForDrag("LeftButton")
    tinsert(UISpecialFrames, self:GetName())
    self.selected = { name = "All messages", count = 0 }
    self.matches = {}
    self.updateToken = 0
    self.groupsStale = false

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("SeamlessChatLogGroupTemplate", function(button, row)
        button:Init(row, self:IsSelected(row))
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.GroupList, self.GroupScrollBar, view)

    local results = self.Results
    results:SetFontObject(ChatFontNormal)
    results:SetJustifyH("LEFT")
    results:SetIndentedWordWrap(true)
    results:SetFading(false)
    results:SetMaxLines(RESULT_LIMIT)
    results:SetHyperlinksEnabled(true)
    -- Item links etc. behave like in the chat: tooltip on click, shift-click links into the chat.
    results:SetScript("OnHyperlinkClick", function(frame, link, text, button)
        SetItemRef(link, text, button, frame)
    end)
    ScrollUtil.InitScrollingMessageFrameWithScrollBar(results, self.ResultScrollBar)

    self.SearchBox:HookScript("OnTextChanged", function()
        self:ScheduleUpdate(SEARCH_DELAY)
    end)
    self.CopyButton:SetScript("OnClick", function()
        self:CopyResults()
    end)
end

function SeamlessChatLogWindowMixin:OnShow()
    -- New messages update the counts, and the results while they are scrolled to the newest.
    app.chatLog.onAdd = function()
        self.groupsStale = true
        if self.Results:AtBottom() then
            self:ScheduleUpdate(LIVE_DELAY)
        end
    end
end

function SeamlessChatLogWindowMixin:OnHide()
    app.chatLog.onAdd = nil
    self.Results:Clear()
end

function SeamlessChatLogWindowMixin:OnDragStart()
    self:StartMoving()
end

function SeamlessChatLogWindowMixin:OnDragStop()
    self:StopMovingOrSizing()
end

-- Shows the window, searching for `text` when given.
---@param text string?
function SeamlessChatLogWindowMixin:Open(text)
    self:Show()
    if text then
        self.SearchBox:SetText(text)
    end
    self:RefreshGroups()
    self:Update()
end

function SeamlessChatLogWindowMixin:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Open()
    end
end

---@param row SeamlessChat.LogGroupRow
function SeamlessChatLogWindowMixin:IsSelected(row)
    return row.group == self.selected.group and row.channel == self.selected.channel
end

---@param row SeamlessChat.LogGroupRow
function SeamlessChatLogWindowMixin:Select(row)
    self.selected = row
    self.GroupList:ForEachFrame(function(button)
        button:Init(button.row, self:IsSelected(button.row))
    end)
    self:Update()
end

-- Rebuilds the group list with the current counts: groups without messages are left out, and the
-- channels are listed below "Channels", by name.
function SeamlessChatLogWindowMixin:RefreshGroups()
    self.groupsStale = false
    local chatLog = app.chatLog
    local groups, channels = chatLog:CountGroups()
    ---@type SeamlessChat.LogGroupRow[]
    local rows = { { name = "All messages", count = chatLog:Count() } }
    for _, group in ipairs(chatLog.GROUPS) do
        local count = groups[group.key]
        if count then
            rows[#rows + 1] = { group = group.key, name = group.name, count = count }
            if group.key == "channel" then
                local names = {}
                for name in pairs(channels) do
                    names[#names + 1] = name
                end
                table.sort(names, function(a, b)
                    return a:lower() < b:lower()
                end)
                for _, name in ipairs(names) do
                    rows[#rows + 1] = { group = "channel", channel = name, name = name, count = channels[name] }
                end
            end
        end
    end
    self.GroupList:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
end

-- Fills the results with the newest matches of the selected group and the search text.
function SeamlessChatLogWindowMixin:Update()
    if self.groupsStale then
        self:RefreshGroups()
    end
    local search = self.SearchBox:GetText():match("^%s*(.-)%s*$")
    local matches, total = app.chatLog:Query({
        group = self.selected.group,
        channel = self.selected.channel,
        search = search ~= "" and search or nil,
        limit = RESULT_LIMIT,
    })
    self.matches = matches

    local results = self.Results
    results:Clear()
    for _, record in ipairs(matches) do
        results:AddMessage(app.chatLog:FormatColored(record))
    end
    results:ScrollToBottom()

    if total == 0 then
        self.Status:SetText("No messages match.")
    elseif total > #matches then
        self.Status:SetFormattedText("%d messages match, showing the newest %d.", total, #matches)
    else
        self.Status:SetFormattedText("%d messages.", total)
    end
    self.CopyButton:SetEnabled(#matches > 0)
end

-- Updates once `delay` seconds passed without another call.
---@param delay number
function SeamlessChatLogWindowMixin:ScheduleUpdate(delay)
    self.updateToken = self.updateToken + 1
    local token = self.updateToken
    C_Timer.After(delay, function()
        if token == self.updateToken and self:IsShown() then
            self:Update()
        end
    end)
end

-- The shown messages as plain text in the copy window.
function SeamlessChatLogWindowMixin:CopyResults()
    local lines = {}
    for i, record in ipairs(self.matches) do
        lines[i] = app.chatLog:FormatRecord(record)
    end
    SeamlessChatCopyWindow:ShowText(table.concat(lines, "\n"), "Copy chat log")
end
