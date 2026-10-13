---@type string, SeamlessChat
local appName, app = ...

local log = app.logger

-- Copying chat. The game can't copy text out of a chat window, only out of an edit box, so a line
-- is put into the chat input, selected, where Ctrl+C copies it.
--
-- Click to copy: the timestamp (src/features/timestamps.lua) becomes a link carrying an id; the
-- line itself is kept here under that id until it is too old to still be in a chat window.
--
-- Copy button: a subtle button in the top right corner of every chat window opens the copy window
-- (copywindow.xml) with the window's last lines, selected.
---@class SeamlessChat.Copy : SeamlessChat.Feature
---@field lines table<integer, string> recent chat lines by link id
---@field nextId integer
---@field buttons table<Frame, Button> the copy button of each chat window
local module = { optionsTab = "windows" }

---@class SeamlessChat.CopySettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    clickTimestamp = true, -- clicking a line's timestamp copies the line
    showButton = true, -- the copy button in the chat windows
    windowLines = 500, -- how many of the last lines the copy window shows
}

app.copy = app.features:New(
    "copy",
    module,
    "Copy chat",
    "Copy chat messages: one by clicking its timestamp (it lands in the chat input), or many at once with the copy button in the top right corner of a chat window. The text is selected, ready for Ctrl+C.",
    defaults
) --[[@as SeamlessChat.Copy]]

-- Lines kept for their links. Chat windows keep a few hundred lines at most, so older links are
-- scrolled out anyway.
local MAX_LINES = 1000

-- |Haddon:...|h links are the ones the game hands to addons (EventRegistry "SetItemRef").
local LINK_PREFIX = "addon:" .. appName .. ":copy:"
local LINK_PATTERN = "^addon:" .. appName .. ":copy:(%d+)"
-- The whole link inside a chat line, capturing its display text.
local OWN_LINK = "|H" .. LINK_PREFIX .. "%d+|h(.-)|h"

-- The line as plain text: links become their text ("[Hearthstone]"), colors and icons go.
---@param message string
local function plainText(message)
    if C_StringUtil and C_StringUtil.StripHyperlinks then
        local ok, text = pcall(C_StringUtil.StripHyperlinks, message, false, true, true, false, false)
        if ok and text then
            return tostring(text)
        end
    end
    local text = message
        :gsub("|H.-|h(.-)|h", "%1")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|cn.-:", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
        :gsub("|n", " ")
    return text
end

-- The line as plain text, for other features (log.lua).
---@param message string
---@return string
function module:PlainText(message)
    return plainText(message)
end

-- `display` (the timestamp) as a link that copies the line, timestamp included, or `display`
-- unchanged when click to copy is off or the line can't be kept (secret values can't be copied).
---@param display string
---@param message any the chat line, without the timestamp
---@return string
function module:WrapTimestamp(display, message)
    if not (self:IsEnabled() and self:GetSettings().clickTimestamp) then
        return display
    end
    if (issecretvalue and issecretvalue(message)) or type(message) ~= "string" then
        return display
    end
    return ("|H%s%d|h%s|h"):format(LINK_PREFIX, self:Remember(display .. " " .. message), display)
end

-- Keeps `line` for a copy link; returns its id.
---@param line string
---@return integer
function module:Remember(line)
    local id = self.nextId
    self.nextId = id + 1
    self.lines[id] = line
    self.lines[id - MAX_LINES] = nil
    return id
end

-- A copy link in a line from an earlier session (history.lua) points at that session's ids: give
-- it a new one, or unwrap it while click to copy is off.
---@param message string
---@return string
function module:Relink(message)
    local unlinked, count = message:gsub(OWN_LINK, "%1", 1)
    if count == 0 then
        return message
    end
    if not (self:IsEnabled() and self:GetSettings().clickTimestamp) then
        return unlinked
    end
    local id = self:Remember(unlinked)
    return (message:gsub(OWN_LINK, ("|H%s%d|h%%1|h"):format(LINK_PREFIX, id), 1))
end

-- Puts `text` into the chat input of `chatFrame` (or the active one), selected.
---@param text string
---@param chatFrame Frame?
function module:CopyToChatInput(text, chatFrame)
    -- No text for OpenChat: it would set it on the next frame, over ours.
    local editBox = ChatFrameUtil.OpenChat(nil, chatFrame)
    if not editBox then
        return
    end
    editBox:SetText(text)
    editBox:HighlightText()
end

---@param link string
local function linkId(link)
    return type(link) == "string" and tonumber(link:match(LINK_PATTERN)) or nil
end

function module:OnSetItemRef(link, _, _, chatFrame)
    local id = linkId(link)
    if not id then
        return
    end
    local message = self.lines[id]
    if not message then
        log:chat("That line is too old to copy.")
        return
    end
    self:CopyToChatInput(plainText(message), chatFrame)
end

-- Copy window ------------------------------------------------------------------------------------

-- The last `count` lines of `chatFrame` as plain text, oldest first. Secret lines are left out.
---@param chatFrame Frame
---@param count integer
function module:GetRecentText(chatFrame, count)
    local lines = {}
    local total = chatFrame:GetNumMessages()
    -- GetMessageInfo(1) is the oldest line.
    for i = math.max(1, total - count + 1), total do
        local message = chatFrame:GetMessageInfo(i)
        if type(message) == "string" and not (issecretvalue and issecretvalue(message)) then
            lines[#lines + 1] = plainText(message)
        end
    end
    return table.concat(lines, "\n")
end

---@param chatFrame Frame
function module:OpenWindow(chatFrame)
    SeamlessChatCopyWindow:ShowText(self:GetRecentText(chatFrame, self:GetSettings().windowLines))
end

-- Copy button ------------------------------------------------------------------------------------

local BUTTON_TEXTURE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local BUTTON_SIZE = 22
-- Distance from the chat window's top and right edges.
local BUTTON_PADDING = 8
-- Hidden until the mouse is over the chat (when the game fades the chat in), faint then, full on
-- hover. The fade is the button's own: UIFrameFadeIn's shared list is Blizzard's to use.
local BUTTON_ALPHA = 0.4
local BUTTON_HOVER_ALPHA = 1
local FADE_PER_SECOND = 4

local function fadeUpdate(button, elapsed)
    local current, target = button:GetAlpha(), button.targetAlpha
    local step = FADE_PER_SECOND * elapsed
    if math.abs(target - current) <= step then
        button:SetAlpha(target)
        button:SetScript("OnUpdate", nil)
    else
        button:SetAlpha(current + (target > current and step or -step))
    end
end

local function fadeTo(button, alpha)
    button.targetAlpha = alpha
    button:SetScript("OnUpdate", fadeUpdate)
end

---@param chatFrame Frame
function module:CreateButton(chatFrame)
    local button = CreateFrame("Button", nil, chatFrame)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -BUTTON_PADDING, -BUTTON_PADDING)
    button:SetFrameLevel(chatFrame:GetFrameLevel() + 10)
    button:SetNormalTexture(BUTTON_TEXTURE)
    button:GetNormalTexture():SetDesaturated(true)
    button:SetHighlightTexture(BUTTON_TEXTURE, "ADD")
    button:SetAlpha(0)
    button:SetScript("OnClick", function()
        self:OpenWindow(chatFrame)
    end)
    button:SetScript("OnEnter", function()
        fadeTo(button, BUTTON_HOVER_ALPHA)
    end)
    button:SetScript("OnLeave", function()
        fadeTo(button, chatFrame.hasBeenFaded and BUTTON_ALPHA or 0)
    end)
    self.buttons[chatFrame] = button
end

-- Creates the buttons of new chat windows and shows or hides all of them.
function module:UpdateButtons()
    local show = self:IsEnabled() and self:GetSettings().showButton
    for _, name in ipairs(CHAT_FRAMES) do
        local chatFrame = _G[name]
        if chatFrame and not IsCombatLog(chatFrame) then
            if show and not self.buttons[chatFrame] then
                self:CreateButton(chatFrame)
            end
            if self.buttons[chatFrame] then
                self.buttons[chatFrame]:SetShown(show)
            end
        end
    end
end

-- Lifecycle --------------------------------------------------------------------------------------

function module:OnInitialize()
    self.lines = {}
    self.nextId = 1
    self.buttons = {}
    -- Links already in the chat keep working while the feature is off; the callback only acts on
    -- this addon's own links.
    EventRegistry:RegisterCallback("SetItemRef", self.OnSetItemRef, self)

    -- The game fades a chat window in while the mouse is over it; the button follows.
    hooksecurefunc("FCF_FadeInChatFrame", function(chatFrame)
        local button = self.buttons[chatFrame]
        if button and not button:IsMouseOver() then
            fadeTo(button, BUTTON_ALPHA)
        end
    end)
    hooksecurefunc("FCF_FadeOutChatFrame", function(chatFrame)
        local button = self.buttons[chatFrame]
        if button and not button:IsMouseOver() then
            fadeTo(button, 0)
        end
    end)
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        if self:IsEnabled() then
            self:UpdateButtons()
        end
    end)
end

function module:OnEnable()
    self:UpdateButtons()
end

function module:OnDisable()
    self:UpdateButtons()
    SeamlessChatCopyWindow:Hide()
end

function module:Refresh()
    self:UpdateButtons()
end

function module:GetOptions()
    return {
        clickTimestamp = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Click a timestamp to copy its message",
            desc = "Needs Timestamps to be enabled.",
        },
        showButton = {
            type = "toggle",
            order = 20,
            width = "full",
            name = "Copy button in the chat windows",
            desc = "A button in the top right corner of each chat window, shown while the mouse is over the chat. It opens a window with the last messages, selected, ready for Ctrl+C.",
        },
        windowLines = {
            type = "range",
            order = 30,
            width = "double",
            name = "Messages in the copy window",
            desc = "How many of the last messages the copy window shows, at most as many as the chat window keeps (Chat history).",
            min = 10,
            max = 10000,
            softMax = 2000,
            step = 1,
            bigStep = 50,
        },
    }
end
