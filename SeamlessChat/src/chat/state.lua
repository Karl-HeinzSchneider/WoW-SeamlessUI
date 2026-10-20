---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local log = app.logger

-- Reads and writes the chat setup the game keeps per character: the chat windows (tabs) with the
-- message types and channels each one shows, the chat colors, the joined custom channels and the
-- main chat window's position and size in the Edit Mode layout.
-- Applying compares first and only touches what differs, so applying a snapshot that already
-- matches leaves Blizzard's chat frames alone.

---@class SeamlessChat.ChatState
local state = {}
app.chatState = state

---@class SeamlessChat.Window
---@field name string
---@field size number font size
---@field r number background color
---@field g number
---@field b number
---@field a number background alpha
---@field shown boolean
---@field docked integer? position in the dock (tab order); nil when floating or closed
---@field locked boolean
---@field uninteractable boolean
---@field messages string[] message groups (keys of ChatTypeGroup)
---@field channels string[] channel names
---@field point string? floating windows only: saved position (screen fractions) and size
---@field x number?
---@field y number?
---@field width number?
---@field height number?

---@class SeamlessChat.Color
---@field r number
---@field g number
---@field b number
---@field classColor boolean names in class colors

-- Where Edit Mode puts the main chat window (ChatFrame1): its anchor, offsets at scale 1.
---@class SeamlessChat.ChatFrameLayout
---@field point string
---@field relativeTo string frame name
---@field relativePoint string
---@field x number
---@field y number
---@field width integer
---@field height integer

---@class SeamlessChat.Snapshot
---@field windows table<integer, SeamlessChat.Window>?
---@field colors table<string, SeamlessChat.Color>?
---@field channels string[]? joined custom channels
---@field chatFrame SeamlessChat.ChatFrameLayout? position and size of the main chat window
---@field savedBy string? "Name-Realm" of the character that saved it
---@field savedAt integer? time()

-- Channels a window should show but the game refused to add on this character (a zone channel
-- outside its zone, a channel not joined yet), per window id. Kept in the snapshot so one
-- character can't drop them for everyone.
---@alias SeamlessChat.MissingChannels table<integer, table<string, true>>

local MAX_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows

-- Helpers ---------------------------------------------------------------------------------------

local function toSet(list)
    local set = {}
    -- pairs, not ipairs: Blizzard's frame lists get holes when an entry is removed.
    for _, value in pairs(list) do
        set[value] = true
    end
    return set
end

local function sameMembers(a, b)
    local setA, setB = toSet(a), toSet(b)
    for value in pairs(setA) do
        if not setB[value] then
            return false
        end
    end
    for value in pairs(setB) do
        if not setA[value] then
            return false
        end
    end
    return true
end

local function sameList(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function near(a, b, epsilon)
    return math.abs((a or 0) - (b or 0)) <= (epsilon or 0.005)
end

-- GetChatWindowChannels returns name, zoneChannelID pairs.
local function channelNames(...)
    local names = {}
    for i = 1, select("#", ...), 2 do
        names[#names + 1] = select(i, ...)
    end
    return names
end

-- ChatFrame1-10, except the voice transcription window, whose visibility follows voice chat.
local function isSynced(id)
    local frame = FCF_GetChatFrameByID(id)
    return frame ~= nil and not IsVoiceTranscription(frame)
end

---@param window SeamlessChat.Window
local function isOpen(window)
    return window.shown or window.docked ~= nil
end

-- Windows ---------------------------------------------------------------------------------------

---@return SeamlessChat.Window
local function captureWindow(id)
    local name, size, r, g, b, a, shown, locked, docked, uninteractable = FCF_GetChatWindowInfo(id)
    ---@type SeamlessChat.Window
    local window = {
        name = name,
        size = size,
        r = r,
        g = g,
        b = b,
        a = a,
        shown = shown and true or false,
        docked = type(docked) == "number" and docked > 0 and docked or nil,
        locked = locked and true or false,
        uninteractable = uninteractable and true or false,
        messages = { GetChatWindowMessages(id) },
        channels = channelNames(GetChatWindowChannels(id)),
    }
    -- ChatFrame1 is the dock's primary window and always its first tab.
    if id == 1 then
        window.docked = 1
    end
    if not window.docked then
        window.point, window.x, window.y = GetChatWindowSavedPosition(id)
        window.width, window.height = GetChatWindowSavedDimensions(id)
    end
    return window
end

-- The synced windows by id, as the game has them now. With `missing`, channels the game refused
-- are added back, and the entries of closed windows are dropped from `missing`.
---@param missing SeamlessChat.MissingChannels?
---@return table<integer, SeamlessChat.Window>
function state.CaptureWindows(missing)
    local windows = {}
    for id = 1, MAX_WINDOWS do
        if isSynced(id) then
            local window = captureWindow(id)
            if missing and missing[id] then
                if isOpen(window) then
                    local have = toSet(window.channels)
                    for channel in pairs(missing[id]) do
                        if not have[channel] then
                            window.channels[#window.channels + 1] = channel
                        end
                    end
                else
                    missing[id] = nil
                end
            end
            windows[id] = window
        end
    end
    return windows
end

-- Ids of the docked windows in tab order, counting only windows `other` has as well.
local function dockOrder(windows, other)
    local ids = {}
    for id, window in pairs(windows) do
        if window.docked and other[id] and isSynced(id) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids, function(x, y)
        if windows[x].docked ~= windows[y].docked then
            return windows[x].docked < windows[y].docked
        end
        return x < y
    end)
    return ids
end

-- Everything but the tab order and the window's contents.
---@param window SeamlessChat.Window
---@param other SeamlessChat.Window
local function sameLayout(window, other)
    if isOpen(window) ~= isOpen(other) then
        return false
    end
    if not isOpen(window) then
        return true
    end
    if window.name ~= other.name or window.size ~= other.size or window.uninteractable ~= other.uninteractable then
        return false
    end
    if
        not (
            near(window.r, other.r)
            and near(window.g, other.g)
            and near(window.b, other.b)
            and near(window.a, other.a)
        )
    then
        return false
    end
    if (window.docked == nil) ~= (other.docked == nil) then
        return false
    end
    -- A docked window's lock and position belong to the dock, and whether it is shown changes with
    -- every tab switch.
    if window.docked then
        return true
    end
    return window.locked == other.locked
        and window.point == other.point
        and near(window.x, other.x, 0.001)
        and near(window.y, other.y, 0.001)
        and near(window.width, other.width, 1)
        and near(window.height, other.height, 1)
end

---@param window SeamlessChat.Window
---@param other SeamlessChat.Window
local function sameContent(window, other)
    if not isOpen(window) then
        return true
    end
    return sameMembers(window.messages, other.messages) and sameMembers(window.channels, other.channels)
end

---@param a table<integer, SeamlessChat.Window>?
---@param b table<integer, SeamlessChat.Window>?
function state.WindowsEqual(a, b)
    if a == nil or b == nil then
        return a == b
    end
    for id = 1, MAX_WINDOWS do
        local window, other = a[id], b[id]
        if (window == nil) ~= (other == nil) then
            return false
        end
        if window and not (sameLayout(window, other) and sameContent(window, other)) then
            return false
        end
    end
    return sameList(dockOrder(a, b), dockOrder(b, a))
end

-- Opens, closes, docks and styles the windows like `stored`. The settings are written where the game
-- keeps them, then Blizzard's own FloatingChatFrame_Update applies them, as it does at login.
---@param stored table<integer, SeamlessChat.Window>
local function applyLayout(stored)
    local dock = GENERAL_CHAT_DOCK
    local selected = FCFDock_GetSelectedWindow(dock)

    -- FCF_DockFrame ignores a window that is already docked, so the stored tab order can only be
    -- restored by taking the windows out of the dock first.
    local dockedFrames = FCFDock_GetChatFrames(dock)
    for i = #dockedFrames, 1, -1 do
        local frame = dockedFrames[i]
        local id = frame:GetID()
        if frame ~= DEFAULT_CHAT_FRAME and stored[id] and isSynced(id) then
            FCF_UnDockFrame(frame)
        end
    end

    local order = {}
    for id, window in pairs(stored) do
        if isSynced(id) then
            SetChatWindowName(id, window.name or "")
            SetChatWindowColor(id, window.r, window.g, window.b)
            SetChatWindowAlpha(id, window.a)
            SetChatWindowLocked(id, window.locked)
            SetChatWindowUninteractable(id, window.uninteractable)
            -- Docked windows count as shown; the dock hides the tabs that aren't selected.
            SetChatWindowShown(id, isOpen(window))
            SetChatWindowDocked(id, window.docked)
            if not window.docked and window.point then
                SetChatWindowSavedPosition(id, window.point, window.x, window.y)
            end
            if not window.docked and window.width and window.height then
                SetChatWindowSavedDimensions(id, window.width, window.height)
            end
            order[#order + 1] = id
        end
    end

    -- Docked windows first and in tab order, so each one is appended at its place.
    table.sort(order, function(x, y)
        local dockedX, dockedY = stored[x].docked or math.huge, stored[y].docked or math.huge
        if dockedX ~= dockedY then
            return dockedX < dockedY
        end
        return x < y
    end)
    for _, id in ipairs(order) do
        FloatingChatFrame_Update(id, true)
        if isOpen(stored[id]) and stored[id].size then
            FCF_SetChatWindowFontSize(nil, FCF_GetChatFrameByID(id), stored[id].size)
        end
    end

    if not (selected and selected.isDocked) then
        selected = DEFAULT_CHAT_FRAME
    end
    FCFDock_SelectWindow(dock, selected)
    FCF_DockUpdate()
end

-- Sets the message types and channels a window shows. Returns whether they changed.
local function applyContent(frame, window)
    local id = frame:GetID()
    local changed = false

    local messages = { GetChatWindowMessages(id) }
    if not (sameMembers(messages, window.messages) and sameMembers(frame.messageTypeList, window.messages)) then
        frame:RemoveAllMessageGroups()
        -- Groups the game has but the frame didn't know about.
        for _, group in ipairs({ GetChatWindowMessages(id) }) do
            RemoveChatWindowMessages(id, group)
        end
        for _, group in ipairs(window.messages) do
            frame:AddMessageGroup(group)
        end
        changed = not sameMembers(messages, { GetChatWindowMessages(id) })
    end

    local channels = channelNames(GetChatWindowChannels(id))
    if not (sameMembers(channels, window.channels) and sameMembers(frame.channelList, window.channels)) then
        frame:RemoveAllChannels()
        for _, channel in ipairs(channelNames(GetChatWindowChannels(id))) do
            RemoveChatWindowChannel(id, channel)
        end
        for _, channel in ipairs(window.channels) do
            frame:AddChannel(channel)
        end
        changed = changed or not sameMembers(channels, channelNames(GetChatWindowChannels(id)))
    end

    return changed
end

-- Makes the chat windows match `stored`. Returns whether anything changed, and the channels the
-- game refused to add.
---@param stored table<integer, SeamlessChat.Window>
---@return boolean changed
---@return SeamlessChat.MissingChannels missing
function state.ApplyWindows(stored)
    local current = state.CaptureWindows()
    local changed = false

    local layoutDiffers = not sameList(dockOrder(current, stored), dockOrder(stored, current))
    for id, window in pairs(stored) do
        if current[id] and not sameLayout(current[id], window) then
            layoutDiffers = true
        end
    end
    if layoutDiffers then
        applyLayout(stored)
        changed = true
    end

    ---@type SeamlessChat.MissingChannels
    local missing = {}
    for id, window in pairs(stored) do
        if isSynced(id) and isOpen(window) then
            if applyContent(FCF_GetChatFrameByID(id), window) then
                changed = true
            end
            local have = toSet(channelNames(GetChatWindowChannels(id)))
            for _, channel in ipairs(window.channels) do
                if not have[channel] then
                    missing[id] = missing[id] or {}
                    missing[id][channel] = true
                end
            end
        end
    end

    return changed, missing
end

-- Colors ----------------------------------------------------------------------------------------

-- The color of every chat type, or nil while the game still has its placeholder colors (all
-- white until the chat settings have loaded).
---@return table<string, SeamlessChat.Color>?
function state.CaptureColors()
    local colors, loaded = {}, false
    for chatType, info in pairs(ChatTypeInfo) do
        if info.r and info.g and info.b then
            colors[chatType] = {
                r = info.r,
                g = info.g,
                b = info.b,
                classColor = info.colorNameByClass and true or false,
            }
            if info.r ~= 1 or info.g ~= 1 or info.b ~= 1 then
                loaded = true
            end
        end
    end
    return loaded and colors or nil
end

-- `stored` updated with `captured`; chat types only `stored` knows are kept.
---@param stored table<string, SeamlessChat.Color>?
---@param captured table<string, SeamlessChat.Color>?
---@return table<string, SeamlessChat.Color>?
function state.MergeColors(stored, captured)
    if not captured then
        return stored
    end
    local merged = stored and CopyTable(stored) or {}
    for chatType, color in pairs(captured) do
        merged[chatType] = color
    end
    return merged
end

local function sameColor(a, b)
    return near(a.r, b.r) and near(a.g, b.g) and near(a.b, b.b) and a.classColor == b.classColor
end

---@param a table<string, SeamlessChat.Color>?
---@param b table<string, SeamlessChat.Color>?
function state.ColorsEqual(a, b)
    if a == nil or b == nil then
        return a == b
    end
    for chatType, color in pairs(a) do
        if not (b[chatType] and sameColor(color, b[chatType])) then
            return false
        end
    end
    for chatType in pairs(b) do
        if not a[chatType] then
            return false
        end
    end
    return true
end

-- Returns whether anything changed.
---@param colors table<string, SeamlessChat.Color>
function state.ApplyColors(colors)
    local changed = false
    for chatType, color in pairs(colors) do
        local info = ChatTypeInfo[chatType]
        if info then
            -- pcall: a chat type this client lists but can't recolor must not stop the others.
            if not (near(info.r, color.r) and near(info.g, color.g) and near(info.b, color.b)) then
                changed = pcall(ChangeChatColor, chatType, color.r, color.g, color.b) or changed
            end
            if (info.colorNameByClass and true or false) ~= color.classColor then
                changed = pcall(SetChatColorNameByClass, chatType, color.classColor) or changed
            end
        end
    end
    return changed
end

-- Channels --------------------------------------------------------------------------------------

local function isCustomChannel(name)
    local info = C_ChatInfo.GetChannelInfoFromIdentifier(name)
    return info ~= nil and info.channelType == Enum.PermanentChatChannelType.Custom
end

-- The custom (player-made) channels this character is in, in channel number order. Zone channels
-- (General, Trade, ...) are left out: the game joins those by itself.
---@return string[]
function state.CaptureChannels()
    local names = {}
    local function collect(...)
        -- GetChannelList returns id, name, disabled triples.
        for i = 1, select("#", ...), 3 do
            local name = select(i + 1, ...)
            if name and isCustomChannel(name) then
                names[#names + 1] = name
            end
        end
    end
    collect(GetChannelList())
    return names
end

-- `stored` plus the channels of `captured` it doesn't have yet.
---@param stored string[]?
---@param captured string[]
---@return string[]
function state.MergeChannels(stored, captured)
    local merged, have = {}, {}
    for _, list in ipairs({ stored or {}, captured }) do
        for _, name in ipairs(list) do
            if not have[name:lower()] then
                have[name:lower()] = true
                merged[#merged + 1] = name
            end
        end
    end
    return merged
end

---@param a string[]?
---@param b string[]?
function state.ChannelsEqual(a, b)
    if a == nil or b == nil then
        return a == b
    end
    return sameMembers(a, b)
end

-- Joins the channels this character isn't in. Joining completes asynchronously. Returns how many
-- were requested.
---@param names string[]
function state.JoinChannels(names)
    local joined = 0
    for _, name in ipairs(names) do
        if GetChannelName(name) == 0 then
            JoinPermanentChannel(name)
            joined = joined + 1
        end
    end
    return joined
end

-- Chat window position (Edit Mode) --------------------------------------------------------------

-- The main chat window is an Edit Mode system: its position and size are part of the active Edit
-- Mode layout, which Edit Mode re-applies over anything set on the frame directly. They are
-- written into the layout with LibEditModeOverride instead.

local editMode = LibStub("LibEditModeOverride-1.0")
local ChatFrameSetting = Enum.EditModeChatFrameSetting

---@return table? systemInfo the chat window's entry in the active layout
local function chatFrameSystemInfo()
    if not (EditModeManagerFrame and editMode:IsReady()) then
        return nil
    end
    return EditModeManagerFrame:GetActiveLayoutSystemInfo(ChatFrame1.system, ChatFrame1.systemIndex)
end

-- A size is stored as two settings, hundreds and the rest (a setting holds small numbers only).
local function compositeSetting(systemInfo, hundreds, tensAndOnes)
    local values = {}
    for _, item in ipairs(systemInfo.settings) do
        values[item.setting] = item.value
    end
    if values[hundreds] and values[tensAndOnes] then
        return values[hundreds] * 100 + values[tensAndOnes]
    end
end

-- The chat window's position and size in the active Edit Mode layout, or nil while Edit Mode
-- hasn't loaded the layouts or is open (its unsaved changes are in the layout already).
---@return SeamlessChat.ChatFrameLayout?
function state.CaptureChatFrame()
    local systemInfo = chatFrameSystemInfo()
    if not systemInfo or EditModeManagerFrame:IsEditModeActive() then
        return nil
    end
    local anchor = systemInfo.anchorInfo
    local relativeTo = anchor.relativeTo
    if type(relativeTo) == "table" then
        relativeTo = relativeTo:GetName()
    end
    local width = compositeSetting(systemInfo, ChatFrameSetting.WidthHundreds, ChatFrameSetting.WidthTensAndOnes)
    local height = compositeSetting(systemInfo, ChatFrameSetting.HeightHundreds, ChatFrameSetting.HeightTensAndOnes)
    if not (anchor.point and width and height) then
        return nil
    end
    ---@type SeamlessChat.ChatFrameLayout
    return {
        point = anchor.point,
        relativeTo = relativeTo or "UIParent",
        relativePoint = anchor.relativePoint,
        x = anchor.offsetX,
        y = anchor.offsetY,
        width = width,
        height = height,
    }
end

---@param a SeamlessChat.ChatFrameLayout?
---@param b SeamlessChat.ChatFrameLayout?
function state.ChatFrameEqual(a, b)
    if a == nil or b == nil then
        return a == b
    end
    return a.point == b.point
        and a.relativeTo == b.relativeTo
        and a.relativePoint == b.relativePoint
        and near(a.x, b.x, 0.5)
        and near(a.y, b.y, 0.5)
        and a.width == b.width
        and a.height == b.height
end

-- Writes `stored` into the active Edit Mode layout and applies it. Returns whether it changed
-- anything, and why not when it couldn't:
-- "notReady" (Edit Mode hasn't loaded the layouts yet), "editMode" (Edit Mode is open), "combat",
-- "preset" (the active layout is one of the game's presets, which can't be changed), "anchor" (the
-- frame it is anchored to doesn't exist), "failed" (the library refused; the error is logged).
---@param stored SeamlessChat.ChatFrameLayout
---@return boolean changed
---@return string? reason
function state.ApplyChatFrame(stored)
    if not chatFrameSystemInfo() then
        return false, "notReady"
    end
    if EditModeManagerFrame:IsEditModeActive() then
        return false, "editMode"
    end
    if state.ChatFrameEqual(state.CaptureChatFrame(), stored) then
        return false
    end
    if InCombatLockdown() then
        return false, "combat"
    end
    local relativeTo = _G[stored.relativeTo]
    if type(relativeTo) ~= "table" then
        return false, "anchor"
    end

    -- ApplyChanges opens and closes Edit Mode, which selects the chat window's own tab.
    local selected = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local ok, result = pcall(function()
        editMode:LoadLayouts()
        if not editMode:CanEditActiveLayout() then
            return "preset"
        end
        editMode:ReanchorFrame(ChatFrame1, stored.point, relativeTo, stored.relativePoint, stored.x, stored.y)
        local width, height = math.floor(stored.width), math.floor(stored.height)
        editMode:SetFrameSetting(ChatFrame1, ChatFrameSetting.WidthHundreds, math.floor(width / 100))
        editMode:SetFrameSetting(ChatFrame1, ChatFrameSetting.WidthTensAndOnes, width % 100)
        editMode:SetFrameSetting(ChatFrame1, ChatFrameSetting.HeightHundreds, math.floor(height / 100))
        editMode:SetFrameSetting(ChatFrame1, ChatFrameSetting.HeightTensAndOnes, height % 100)
        editMode:ApplyChanges()
    end)
    if not ok then
        log:debug(L["Couldn't place the chat window: %s"], tostring(result))
        return false, "failed"
    end
    if result then
        return false, result
    end
    if selected and selected.isDocked and selected ~= FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) then
        FCFDock_SelectWindow(GENERAL_CHAT_DOCK, selected)
    end
    return true
end

-- Snapshots -------------------------------------------------------------------------------------

---@param a SeamlessChat.Snapshot
---@param b SeamlessChat.Snapshot
function state.SnapshotsEqual(a, b)
    return state.WindowsEqual(a.windows, b.windows)
        and state.ColorsEqual(a.colors, b.colors)
        and state.ChannelsEqual(a.channels, b.channels)
        and state.ChatFrameEqual(a.chatFrame, b.chatFrame)
end
