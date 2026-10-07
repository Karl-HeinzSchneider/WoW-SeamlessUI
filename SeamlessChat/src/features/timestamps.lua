---@type string, SeamlessChat
local _, app = ...

-- Puts the time in front of every chat message: [18:14:31] Hello. Unlike the game's own chat
-- timestamps, it covers every message (loot, system, ...), not just player chat, and its format is
-- free. The game's timestamps are switched off while it is enabled, or every line would get two.
---@class SeamlessChat.Timestamps : SeamlessChat.Feature
---@field stamping boolean new lines get a stamp
---@field unstampedSince number GetTime() since when lines went in without a stamp
---@field cachedTime integer? time() the cached stamp is for
---@field cachedStamp string?
local module = {}

---@class SeamlessChat.TimestampSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    format = "%H:%M:%S", -- one of FORMATS, or "custom" for customFormat
    customFormat = "%H:%M:%S",
    brackets = "square", -- key of BRACKETS
    colored = false, -- own color instead of the message's
    color = { r = 0.6, g = 0.6, b = 0.6 },
}

local timestamps = app.features:New(
    "timestamps",
    module,
    "Timestamps",
    "Shows the time in front of every chat message. Replaces the game's own chat timestamps while enabled.",
    defaults
) --[[@as SeamlessChat.Timestamps]]

-- Where the game's chat timestamp setting was before this feature switched it off (account-wide,
-- like the CVar), so disabling the feature can restore it.
---@class SeamlessChat.DB.Global
---@field blizzardTimestamps string?

-- date() patterns, in the order the options list them.
local FORMATS = { "%H:%M:%S", "%H:%M", "%I:%M:%S %p", "%I:%M %p" }

local BRACKETS = {
    square = { "[", "]" },
    round = { "(", ")" },
    angle = { "<", ">" },
    none = { "", "" },
}
local BRACKET_ORDER = { "square", "round", "angle", "none" }

-- 18:14:31 today, for the previews in the options.
local EXAMPLE_TIME = time({ year = 2026, month = 1, day = 1, hour = 18, min = 14, sec = 31 })

---@param settings SeamlessChat.TimestampSettings
---@param timeValue integer
---@param pattern string? instead of the settings' format
local function formatStamp(settings, timeValue, pattern)
    pattern = pattern or (settings.format == "custom" and settings.customFormat or settings.format)
    -- TimeUtil.BetterDate localizes %p; a broken custom format falls back to the default.
    local ok, text = pcall(TimeUtil.BetterDate, pattern, timeValue)
    if not ok then
        text = date(defaults.format, timeValue)
    end
    local brackets = BRACKETS[settings.brackets] or BRACKETS.square
    text = brackets[1] .. text .. brackets[2]
    if settings.colored then
        local color = settings.color
        text = ("|cff%02x%02x%02x%s|r"):format(
            math.floor(color.r * 255 + 0.5),
            math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5),
            text
        )
    end
    return text
end

-- The stamp for now, recomputed once a second at most.
function module:GetStamp()
    local now = time()
    if now ~= self.cachedTime then
        self.cachedTime = now
        self.cachedStamp = formatStamp(self:GetSettings() --[[@as SeamlessChat.TimestampSettings]], now)
    end
    return self.cachedStamp
end

-- `message` with the stamp for `timeValue` (now when nil) in front. Chat lines can be secret values:
-- concatenating them is allowed, anything else isn't.
---@param feature SeamlessChat.Timestamps
---@param timeValue integer?
local function stamp(feature, message, timeValue)
    local display = timeValue and formatStamp(feature:GetSettings() --[[@as SeamlessChat.TimestampSettings]], timeValue)
        or feature:GetStamp()
    -- Copy chat (src/features/copy.lua) makes the stamp a link that copies the line.
    return app.copy:WrapTimestamp(display, message) .. " " .. message
end

-- The last line transform (src/chat/lines.lua), so the copy link holds the line as shown. It runs on
-- secret lines too: the stamp is only concatenated.
app.lines:Register(1000, function(_, message)
    if not timestamps.stamping then
        return message
    end
    return stamp(timestamps, message)
end, true)

-- Stamps the lines already in the chat that arrived since `since` (GetTime()), with the time each
-- one arrived: the lines printed before the settings loaded, or while the feature was off.
function module:Backfill(since)
    local now, clock = time(), GetTime()
    for frame in pairs(app.lines.hooked) do
        if frame.ForEachMessage and not IsCombatLog(frame) then
            local changed = false
            frame:ForEachMessage(function(entry)
                if entry.timestamp and entry.timestamp >= since then
                    local arrived = now - math.floor(clock - entry.timestamp + 0.5)
                    local ok, stamped = pcall(stamp, self, entry.message, arrived)
                    if ok then
                        entry.message = stamped
                        changed = true
                    end
                end
            end)
            if changed then
                frame:MarkDisplayDirty()
            end
        end
    end
end

function module:StartStamping()
    if self.stamping then
        return
    end
    self:Backfill(self.unstampedSince)
    self.stamping = true
end

function module:StopStamping()
    if self.stamping then
        self.stamping = false
        self.unstampedSince = GetTime()
    end
end

-- Runs once the SavedVariables are loaded: from here on the settings are known, so lines can be
-- stamped, the earlier ones included.
function module:OnInitialize()
    if self:IsEnabled() then
        self:StartStamping()
    end
end

function module:OnEnable()
    self:StartStamping()
    local blizzard = C_CVar.GetCVar("showTimestamps")
    if blizzard and blizzard ~= "none" then
        app.db.global.blizzardTimestamps = blizzard
        C_CVar.SetCVar("showTimestamps", "none")
    end
end

function module:OnDisable()
    self:StopStamping()
    local blizzard = app.db.global.blizzardTimestamps
    if blizzard then
        C_CVar.SetCVar("showTimestamps", blizzard)
        app.db.global.blizzardTimestamps = nil
    end
end

function module:Refresh()
    self.cachedTime = nil
end

function module:GetOptions()
    local settings = function()
        return self:GetSettings() --[[@as SeamlessChat.TimestampSettings]]
    end

    return {
        preview = {
            type = "description",
            order = 5,
            fontSize = "medium",
            name = function()
                return "Preview:  " .. formatStamp(settings(), EXAMPLE_TIME) .. " [Thrall]: Lok'tar!\n"
            end,
        },
        format = {
            type = "select",
            order = 10,
            name = "Format",
            values = function()
                local values = { custom = "Custom" }
                for _, pattern in ipairs(FORMATS) do
                    values[pattern] = TimeUtil.BetterDate(pattern, EXAMPLE_TIME)
                end
                return values
            end,
            sorting = { FORMATS[1], FORMATS[2], FORMATS[3], FORMATS[4], "custom" },
        },
        customFormat = {
            type = "input",
            order = 11,
            name = "Custom format",
            desc = "A date() pattern: %H hour (00-23), %I hour (01-12), %M minute, %S second, %p AM/PM, %d day, %m month.",
            hidden = function()
                return settings().format ~= "custom"
            end,
            validate = function(_, value)
                if value == "" or not pcall(date, value) then
                    return "Not a valid time format."
                end
                return true
            end,
        },
        brackets = {
            type = "select",
            order = 20,
            name = "Brackets",
            values = function()
                local values = {}
                for key, brackets in pairs(BRACKETS) do
                    values[key] = brackets[1] .. "18:14" .. brackets[2]
                end
                return values
            end,
            sorting = BRACKET_ORDER,
        },
        colored = {
            type = "toggle",
            order = 30,
            name = "Own color",
            desc = "Color the timestamp instead of showing it in the message's color.",
        },
        color = {
            type = "color",
            order = 31,
            name = "Color",
            disabled = function()
                return not (settings().enabled and settings().colored)
            end,
            get = function()
                local color = settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = settings().color
                color.r, color.g, color.b = r, g, b
                self:Refresh()
            end,
        },
    }
end

-- Lines printed before the settings are known go in unstamped; OnInitialize backfills them.
timestamps.stamping = false
timestamps.unstampedSince = 0
