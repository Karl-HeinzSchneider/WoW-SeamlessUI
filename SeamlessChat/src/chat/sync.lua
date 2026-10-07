---@type string, SeamlessChat
local _, app = ...

local log = app.logger
local addon = app.addon
local chatState = app.chatState

-- Keeps the chat the same on every character. The profile (one shared "Default" profile unless a
-- character is given its own) holds a snapshot of the chat setup: logging in applies it, and any
-- change to the chat, from the chat menus or from another addon, saves it again.
---@class SeamlessChat.Sync : AceModule, AceEvent-3.0
---@field loggedIn boolean the login delay has passed; the chat settings are loaded
---@field ready boolean changes may be saved (false while applying)
---@field busy boolean an apply is in progress
---@field savePending boolean
---@field missingChannels SeamlessChat.MissingChannels
---@field chatFrameEdited boolean the chat window's Edit Mode layout was saved since the last save
---@field presetNoticeShown boolean
local module = {}
app.sync = addon:NewModule("Sync", module, "AceEvent-3.0") --[[@as SeamlessChat.Sync]]

-- Seconds after entering the world before the chat is touched: the chat settings and colors arrive
-- around login, and reading them earlier gets placeholders.
local LOGIN_DELAY = 2
-- A change comes as a burst of setter calls (one per window setting); saving waits for it to end.
-- Also the time the game gets to answer an apply (chat color events) before saving is allowed again.
local SAVE_DELAY = 1
-- Joining a channel completes asynchronously; the windows are applied after this.
local JOIN_DELAY = 3

-- The game's setters for everything in the snapshot. Every change to the chat goes through them.
local WATCHED_FUNCTIONS = {
    "SetChatWindowName",
    "SetChatWindowSize",
    "SetChatWindowColor",
    "SetChatWindowAlpha",
    "SetChatWindowShown",
    "SetChatWindowLocked",
    "SetChatWindowDocked",
    "SetChatWindowUninteractable",
    "SetChatWindowSavedPosition",
    "SetChatWindowSavedDimensions",
    "AddChatWindowMessages",
    "RemoveChatWindowMessages",
    "AddChatWindowChannel",
    "RemoveChatWindowChannel",
    "ResetChatWindows",
    "ChangeChatColor",
    "SetChatColorNameByClass",
}

function module:OnInitialize()
    self.loggedIn = false
    self.ready = false
    self.busy = false
    self.savePending = false
    self.missingChannels = {}
    self.chatFrameEdited = false
    self.presetNoticeShown = false

    -- The chat window is moved and resized in Edit Mode, which saves the layout on its own. Its
    -- position is taken once Edit Mode is closed: until then the layout holds unsaved changes too.
    EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
        if self.ready then
            self.chatFrameEdited = true
        end
    end, self)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if self.chatFrameEdited then
            self:ScheduleSave()
        end
    end, self)

    -- Secure hooks can't be removed, so they are set once and check `ready` instead.
    local function onChange()
        self:ScheduleSave()
    end
    for _, name in ipairs(WATCHED_FUNCTIONS) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, onChange)
        end
    end
    -- A channel the user removes from a window stops counting as refused.
    hooksecurefunc("RemoveChatWindowChannel", function(id, channel)
        if self.ready and self.missingChannels[id] then
            self.missingChannels[id][channel] = nil
        end
    end)
end

function module:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHANNEL_UI_UPDATE", "ScheduleSave")
    self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
end

function module:OnDisable()
    self.ready = false
end

function module:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(LOGIN_DELAY, function()
        self.loggedIn = true
        self:Sync()
    end)
end

-- Leaving a synced channel takes it off the list, so the other characters stop joining it.
function module:CHAT_MSG_CHANNEL_NOTICE(_, notice, _, _, _, _, _, _, _, channelName)
    local stored = app.db.profile.chat
    if not (self.ready and stored and stored.channels) then
        return
    end
    if issecretvalue and (issecretvalue(notice) or issecretvalue(channelName)) then
        return
    end
    if notice ~= "YOU_LEFT" or type(channelName) ~= "string" then
        return
    end
    for i = #stored.channels, 1, -1 do
        if stored.channels[i]:lower() == channelName:lower() then
            table.remove(stored.channels, i)
            log:debug("Stopped syncing channel %s", channelName)
        end
    end
end

-- Brings this character and the profile together: applies the profile's chat setup, or starts one
-- from this character's chat when the profile has none yet.
function module:Sync()
    if not (self.loggedIn and self:IsEnabled()) then
        return
    end
    if app.db.profile.chat then
        self:Apply()
    else
        self.ready = true
        if self:Save() then
            log:info("Saved this character's chat setup; your other characters will get it.")
        end
    end
end

-- Replaces this character's chat with the profile's.
function module:Apply()
    local stored = app.db.profile.chat
    if not (self.loggedIn and stored) or self.busy then
        return
    end
    local options = app.db.profile.sync
    self.busy = true
    self.ready = false

    local changed = false
    local joined = 0
    if options.colors and stored.colors then
        changed = chatState.ApplyColors(stored.colors)
    end
    if options.channels and stored.channels then
        joined = chatState.JoinChannels(stored.channels)
    end

    local function finish()
        if options.windows and stored.windows then
            local windowsChanged, missing = chatState.ApplyWindows(stored.windows)
            self.missingChannels = missing
            changed = changed or windowsChanged
        end
        -- After the windows: the dock is settled, and FCF_DockUpdate doesn't move it again.
        if self:ApplyChatFrame() then
            changed = true
        end
        if changed or joined > 0 then
            log:info("Applied the chat setup saved by %s.", stored.savedBy or "another character")
        end
        C_Timer.After(SAVE_DELAY, function()
            self.busy = false
            self.ready = true
            -- Adds what only this character has (its custom channels, chat types the snapshot lacks).
            self:Save()
        end)
    end

    -- Windows can only show a channel once it is joined.
    if joined > 0 then
        C_Timer.After(JOIN_DELAY, finish)
    else
        finish()
    end
end

-- Puts the main chat window where the profile has it: into the active Edit Mode layout. Waits
-- for Edit Mode to load the layouts and for the end of combat. Returns whether it moved it.
function module:ApplyChatFrame()
    local stored = app.db.profile.chat
    if not (stored and stored.chatFrame and app.db.profile.sync.position) then
        return false
    end
    local changed, reason = chatState.ApplyChatFrame(stored.chatFrame)
    if reason == "combat" then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "RetryChatFrame")
    elseif reason == "notReady" then
        self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "RetryChatFrame")
    elseif reason == "preset" and not self.presetNoticeShown then
        self.presetNoticeShown = true
        log:info(
            "The chat window stays where it is: this character uses one of the game's preset Edit Mode layouts, which can't be changed. Choose or create your own layout in Edit Mode to have it placed like on your other characters."
        )
    elseif reason then
        log:debug("Chat window not placed: %s", reason)
    end
    return changed
end

function module:RetryChatFrame(event)
    self:UnregisterEvent(event)
    -- Next frame: Edit Mode handles EDIT_MODE_LAYOUTS_UPDATED itself first.
    C_Timer.After(0, function()
        if self:ApplyChatFrame() then
            log:debug("Placed the chat window")
        end
    end)
end

function module:ScheduleSave()
    if not self.ready or self.savePending then
        return
    end
    self.savePending = true
    C_Timer.After(SAVE_DELAY, function()
        self.savePending = false
        self:Save()
    end)
end

-- Stores this character's chat setup in the profile if it differs from the stored one (or always,
-- with `force`). Returns whether it saved.
---@param force boolean?
---@return boolean
function module:Save(force)
    if not self.ready then
        return false
    end
    local profile = app.db.profile
    local options = profile.sync
    local stored = profile.chat or {}

    ---@type SeamlessChat.Snapshot
    local snapshot = {
        windows = stored.windows,
        colors = stored.colors,
        channels = stored.channels,
        chatFrame = stored.chatFrame,
    }
    if options.windows then
        snapshot.windows = chatState.CaptureWindows(self.missingChannels)
    end
    if options.colors then
        snapshot.colors = chatState.MergeColors(stored.colors, chatState.CaptureColors())
    end
    if options.channels then
        -- Channels are only ever added here; leaving one removes it (CHAT_MSG_CHANNEL_NOTICE).
        snapshot.channels = chatState.MergeChannels(stored.channels, chatState.CaptureChannels())
    end
    -- Only taken from the game when it was changed in Edit Mode (or on "Save now"): a character
    -- that couldn't apply it (preset layout, combat) must not overwrite it for everyone.
    if options.position and (self.chatFrameEdited or force or not stored.chatFrame) then
        local captured = chatState.CaptureChatFrame()
        if captured then
            snapshot.chatFrame = captured
            self.chatFrameEdited = false
        end
    end

    if profile.chat and not force and chatState.SnapshotsEqual(snapshot, stored) then
        return false
    end
    snapshot.savedBy = UnitName("player") .. "-" .. GetNormalizedRealmName()
    snapshot.savedAt = time()
    profile.chat = snapshot
    log:debug("Saved the chat setup")
    app.options:Refresh()
    return true
end

-- The profile was switched, copied or reset.
function module:OnProfileRefresh()
    self:Sync()
end
