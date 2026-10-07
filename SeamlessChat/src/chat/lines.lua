---@type string, SeamlessChat
local _, app = ...

-- The one place chat lines are changed before a chat window shows them. Every chat window's
-- AddMessage (the method every line goes through, print() included) is wrapped once, at file load,
-- and runs the registered transforms in their order: clickable URLs, short channel names, ...,
-- the timestamp last. A transform checks its own feature's switch.
--
-- Chat lines can be secret values (in restricted content); only transforms registered as
-- `secretSafe` see those, and they may only concatenate them. The combat log isn't touched.

---@class SeamlessChat.Lines
---@field transforms SeamlessChat.LineTransform[] by order
---@field hooked table<Frame, true> chat frames whose AddMessage is wrapped
local lines = { transforms = {}, hooked = {} }
app.lines = lines

---@alias SeamlessChat.LineTransformFunc fun(chatFrame: Frame, message: string, chatType: string?): string

---@class SeamlessChat.LineTransform
---@field order number lower runs first
---@field func SeamlessChat.LineTransformFunc
---@field secretSafe boolean may run on secret lines (concatenation only)

-- Adds a transform; `func(chatFrame, message, chatType)` returns the new line. `chatType` is the
-- chat type the line came from ("GUILD", "PARTY_LEADER", "CHANNEL", ...), nil for print() and
-- other lines that aren't chat messages.
---@param order number
---@param func SeamlessChat.LineTransformFunc
---@param secretSafe boolean?
function lines:Register(order, func, secretSafe)
    self.transforms[#self.transforms + 1] = { order = order, func = func, secretSafe = secretSafe or false }
    table.sort(self.transforms, function(a, b)
        return a.order < b.order
    end)
end

-- Chat type of a line from AddMessage's extra arguments: chat messages pass (r, g, b, infoID,
-- accessID, typeID, event, ...); the event names the type exactly (PARTY_LEADER, not just PARTY).
local function chatTypeOf(...)
    local event = select(7, ...)
    if type(event) == "string" and event:sub(1, 9) == "CHAT_MSG_" then
        return event:sub(10)
    end
end

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- `message` after every transform that applies. A failing transform is skipped: it must never
-- cost the chat line.
function lines:Transform(chatFrame, message, ...)
    if IsCombatLog(chatFrame) then
        return message
    end
    local secret = isSecret(message)
    if not secret and type(message) ~= "string" then
        return message
    end
    local chatType = chatTypeOf(...)
    for _, transform in ipairs(self.transforms) do
        if not secret or transform.secretSafe then
            local ok, changed = pcall(transform.func, chatFrame, message, chatType)
            if ok and changed ~= nil then
                message = changed
            end
        end
    end
    return message
end

-- Wraps a chat frame's AddMessage once. The wrapper stays for the session; transforms that are
-- switched off just return the line unchanged.
function lines:HookFrame(frame)
    if not frame or self.hooked[frame] then
        return
    end
    self.hooked[frame] = true
    local addMessage = frame.AddMessage
    frame.AddMessage = function(chatFrame, message, ...)
        local ok, changed = pcall(self.Transform, self, chatFrame, message, ...)
        if ok then
            message = changed
        end
        return addMessage(chatFrame, message, ...)
    end
end

-- ChatFrame1-10 plus the temporary (whisper) windows opened so far.
function lines:HookFrames()
    for _, name in ipairs(CHAT_FRAMES) do
        self:HookFrame(_G[name])
    end
end

-- Right away, before other addons print while loading.
lines:HookFrames()
hooksecurefunc("FCF_OpenTemporaryWindow", function()
    lines:HookFrames()
end)
