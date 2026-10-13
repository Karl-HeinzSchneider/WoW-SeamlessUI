---@type string, SeamlessChat
local appName, app = ...

-- Clickable URLs: web addresses in chat lines become links; clicking one puts the address into the
-- chat input, selected, ready for Ctrl+C (the game can't open a browser). The address is the link's
-- own data (|Haddon:SeamlessChat:url:<address>|h), so links in restored chat history keep working.
---@class SeamlessChat.Urls : SeamlessChat.Feature
local module = { optionsTab = "messages" }

---@class SeamlessChat.UrlSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    color = { r = 0.25, g = 0.66, b = 0.96 },
}

app.urls = app.features:New(
    "urls",
    module,
    "Clickable URLs",
    "Web addresses in the chat become links. Clicking one puts it into the chat input, selected, ready for Ctrl+C.",
    defaults
) --[[@as SeamlessChat.Urls]]

local LINK_PREFIX = "addon:" .. appName .. ":url:"
local LINK_PATTERN = "^addon:" .. appName .. ":url:(.+)$"

---@return SeamlessChat.UrlSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.UrlSettings]]
end

-- Whether `word` (punctuation around it already cut off) is a web address: with a scheme
-- (https://...), starting with www., or a domain with a path (discord.gg/abc).
local function isUrl(word)
    return word:find("^%a[%w+.-]*://[^/%s]") ~= nil
        or word:find("^www%.[%w-]+%.%a") ~= nil
        or word:find("^[%w-]+%.[%w.-]*%a%a/") ~= nil
end

-- `text` (no links in it) with every web address wrapped in a link.
local function linkifyPlain(text, colorCode)
    return (
        text:gsub("%S+", function(word)
            -- "(https://x.com)." -> "(", "https://x.com", ")."
            local lead, core, trail = word:match("^([%(%[\"'<]*)(.-)([%.,;:!%?%)%]\"'>]*)$")
            if not core or core == "" or core:find("|", 1, true) or not isUrl(core) then
                return word
            end
            return ("%s|cff%s|H%s%s|h[%s]|h|r%s"):format(lead, colorCode, LINK_PREFIX, core, core, trail)
        end)
    )
end

-- `text` with the web addresses outside its existing links (items, players, channels) linked.
---@param text string
---@return string
function module:Linkify(text)
    local color = self:Settings().color
    local colorCode = ("%02x%02x%02x"):format(
        math.floor(color.r * 255 + 0.5),
        math.floor(color.g * 255 + 0.5),
        math.floor(color.b * 255 + 0.5)
    )
    local parts, position = {}, 1
    while true do
        local linkStart, linkEnd = text:find("|H.-|h.-|h", position)
        if not linkStart then
            break
        end
        parts[#parts + 1] = linkifyPlain(text:sub(position, linkStart - 1), colorCode)
        parts[#parts + 1] = text:sub(linkStart, linkEnd)
        position = linkEnd + 1
    end
    parts[#parts + 1] = linkifyPlain(text:sub(position), colorCode)
    return table.concat(parts)
end

function module:OnSetItemRef(link)
    local url = type(link) == "string" and link:match(LINK_PATTERN)
    if url then
        app.copy:CopyToChatInput(url)
    end
end

function module:OnInitialize()
    -- Links already in the chat keep working while the feature is off.
    EventRegistry:RegisterCallback("SetItemRef", self.OnSetItemRef, self)
end

-- First among the line transforms (src/chat/lines.lua): the others add links of their own.
app.lines:Register(10, function(_, message)
    if not app.urls:IsEnabled() then
        return message
    end
    return app.urls:Linkify(message)
end)

function module:GetOptions()
    return {
        color = {
            type = "color",
            order = 10,
            name = "Link color",
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().color
                color.r, color.g, color.b = r, g, b
            end,
        },
    }
end
