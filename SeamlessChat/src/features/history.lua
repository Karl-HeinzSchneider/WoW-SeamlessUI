---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local log = app.logger

-- Chat history: every chat window keeps more messages than the game's 128, and, per character,
-- they are saved at logout/reload and put back at the next login, above that session's messages,
-- with a divider line in between.
--
-- Saved in SeamlessChatHistoryDB (## SavedVariablesPerCharacter), so a character's file only holds
-- its own chat. A saved line is its text as shown (timestamp included) plus its color; the divider
-- isn't saved.
---@class SeamlessChat.History : SeamlessChat.Feature
---@field restored boolean this session's saved chat was put back
---@field dividers table<string, true> the divider lines shown, never saved
local module = { optionsTab = "windows" }

---@class SeamlessChat.HistorySettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    maxLines = 1000, -- messages each chat window keeps
    persist = true, -- save the chat at logout and put it back at login
    savedLines = 1000, -- messages saved per chat window
}

app.features:New(
    "history",
    module,
    L["Chat history"],
    L["Keeps more messages in every chat window, and keeps them across logins and reloads (per character), so scrolling back and the copy window reach into your last session."],
    defaults
)

---@class SeamlessChat.SavedHistory
---@field savedAt integer time()
---@field windows table<integer, SeamlessChat.SavedLine[]> by chat window id, oldest line first

---@class SeamlessChat.SavedLine
---@field [1] string message
---@field [2] number r
---@field [3] number g
---@field [4] number b

-- What the game's chat windows keep (ChatFrameMixin:OnLoad).
local BLIZZARD_MAX_LINES = 128
local MAX_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows
local DIVIDER_COLOR = { r = 0.5, g = 0.5, b = 0.5 }

-- The chat windows history applies to: ChatFrame1-10, the combat log aside (it keeps its own).
-- Closed ones too: a closed window keeps its messages, and whether a window counts as open can
-- still change at login (sync.lua) and at logout.
---@param id integer
---@return Frame?
local function chatWindow(id)
    local chatFrame = FCF_GetChatFrameByID(id)
    if chatFrame and chatFrame.GetMessageInfo and not IsCombatLog(chatFrame) then
        return chatFrame
    end
end

-- Sets the history size of every chat window, temporary (whisper) windows included.
---@param maxLines integer
local function setMaxLines(maxLines)
    for _, name in ipairs(CHAT_FRAMES) do
        local chatFrame = _G[name]
        if chatFrame and chatFrame.SetMaxLines and not IsCombatLog(chatFrame) then
            chatFrame:SetMaxLines(maxLines)
        end
    end
end

---@return SeamlessChat.HistorySettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.HistorySettings]]
end

-- Saving and restoring -----------------------------------------------------------------------------

-- The last `savedLines` messages of every open chat window. Secret lines can't be saved and the
-- dividers aren't.
---@return SeamlessChat.SavedHistory
function module:Capture()
    local count = self:Settings().savedLines
    ---@type SeamlessChat.SavedHistory
    local saved = { savedAt = time(), windows = {} }
    for id = 1, MAX_WINDOWS do
        local chatFrame = chatWindow(id)
        if chatFrame then
            local lines = {}
            local total = chatFrame:GetNumMessages()
            -- GetMessageInfo(1) is the oldest line.
            for i = math.max(1, total - count + 1), total do
                local message, r, g, b = chatFrame:GetMessageInfo(i)
                if
                    type(message) == "string"
                    and not (issecretvalue and issecretvalue(message))
                    and not self.dividers[message]
                then
                    lines[#lines + 1] = { message, r or 1, g or 1, b or 1 }
                end
            end
            if #lines > 0 then
                saved.windows[id] = lines
            end
        end
    end
    return saved
end

-- Puts the saved chat back above what the windows got since login, with a divider below it. A
-- window keeps at most maxLines: what doesn't fit is left out, the oldest lines first. Returns how
-- many messages came back.
---@param saved SeamlessChat.SavedHistory
---@return integer
function module:Restore(saved)
    local divider = (L["-- Restored from your last session (%s) --"]):format(date("%Y-%m-%d %H:%M", saved.savedAt))
    self.dividers[divider] = true

    local restored = 0
    for id, lines in pairs(saved.windows) do
        local chatFrame = chatWindow(id)
        if chatFrame then
            -- BackFillMessage adds a line above all others, and only while the window has room.
            local function hasRoom()
                return chatFrame:GetNumMessages() < chatFrame:GetMaxLines()
            end
            if hasRoom() then
                chatFrame:BackFillMessage(divider, DIVIDER_COLOR.r, DIVIDER_COLOR.g, DIVIDER_COLOR.b)
            end
            for i = #lines, 1, -1 do
                if not hasRoom() then
                    break
                end
                local line = lines[i]
                chatFrame:BackFillMessage(app.copy:Relink(line[1]), line[2], line[3], line[4])
                restored = restored + 1
            end
        end
    end
    return restored
end

-- Stores the chat for the next login, at logout (a reload too). An error here is never shown, so it
-- is saved along and reported at the next login.
--
-- Runs on AceDB's OnDatabaseShutdown, not PLAYER_LOGOUT: AceDB's own PLAYER_LOGOUT handler strips
-- the defaults out of the settings, and a handler running after it would read `persist` as nil.
function module:Save()
    if not (self:IsEnabled() and self:Settings().persist) then
        SeamlessChatHistoryDB = nil
        return
    end
    local ok, result = pcall(self.Capture, self)
    if ok then
        SeamlessChatHistoryDB = result
    else
        SeamlessChatHistoryDB = { savedAt = time(), windows = {}, error = tostring(result) }
    end
end

-- Lifecycle --------------------------------------------------------------------------------------

function module:OnInitialize()
    self.restored = false
    self.dividers = {}
    -- Registered once, whether the feature is on or off: Save checks that itself.
    app.db.RegisterCallback(self, "OnDatabaseShutdown", "Save")
    -- A new temporary (whisper) window starts at the game's size.
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        if self:IsEnabled() then
            setMaxLines(self:Settings().maxLines)
        end
    end)
end

function module:OnEnable()
    setMaxLines(self:Settings().maxLines)
    -- Once per session: at login, or when the feature is switched on later.
    if self.restored then
        return
    end
    self.restored = true
    local saved = SeamlessChatHistoryDB
    if not (self:Settings().persist and type(saved) == "table") then
        return
    end
    if saved.error then
        log:warn(L["Saving the chat at the last logout failed: %s"], saved.error)
    end
    if type(saved.windows) == "table" then
        local ok, result = pcall(self.Restore, self, saved)
        if ok then
            log:debug(L["Restored %d messages from the last session"], result)
        else
            log:warn(L["Restoring the chat of the last session failed: %s"], tostring(result))
        end
    end
end

-- The saved chat stays until the next logout, where Save drops it if the feature is still off.
function module:OnDisable()
    setMaxLines(BLIZZARD_MAX_LINES)
end

function module:Refresh()
    setMaxLines(self:Settings().maxLines)
end

function module:GetOptions()
    return {
        maxLines = {
            type = "range",
            order = 10,
            width = "double",
            name = L["Messages per chat window"],
            desc = L["How many messages each chat window keeps. Lowering it drops the oldest ones."],
            min = BLIZZARD_MAX_LINES,
            max = 10000,
            softMax = 5000,
            step = 1,
            bigStep = 100,
        },
        persist = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Keep the chat across logins and reloads"],
            desc = L["Saves each chat window's messages when you log out or reload and puts them back at the next login of the same character, above a divider line."],
        },
        savedLines = {
            type = "range",
            order = 30,
            width = "double",
            name = L["Messages saved per chat window"],
            desc = L["How many of the last messages of each chat window are saved. At login, a window takes back as many as fit into Messages per chat window."],
            min = 10,
            max = 10000,
            softMax = 5000,
            step = 1,
            bigStep = 100,
            disabled = function()
                return not (self:Settings().enabled and self:Settings().persist)
            end,
        },
    }
end
