---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local log = app.logger

-- One background color and opacity for every chat window and its tab (temporary ones too),
-- whatever each window has saved. Only what is shown changes (the doNotSave path of the game's
-- setters): the windows' own backgrounds, and with them the synced chat setup, stay as they are
-- and come back when disabled. The game redraws a background through FCF_SetWindowColor /
-- FCF_SetWindowAlpha (login, new whisper windows, reset, the tab menu); hooks on them paint ours
-- over it.
---@class SeamlessChat.Background : SeamlessChat.Feature
local module = { optionsTab = "windows" }

---@class SeamlessChat.BackgroundSettings : SeamlessChat.FeatureSettings
app.features:New(
    "background",
    module,
    L["Background"],
    L["The same background color and opacity for every chat window and tab, black by default. While on, the Background setting in a tab's menu has no visible effect."]
)

-- Set while painting, so the hooks don't answer our own calls.
local painting = false

local function paint(chatFrame, r, g, b, a)
    painting = true
    local ok, err = pcall(function()
        FCF_SetWindowColor(chatFrame, r, g, b, true)
        FCF_SetWindowAlpha(chatFrame, a, true)
    end)
    painting = false
    if not ok then
        log:debug(L["Couldn't paint the background of %s: %s"], chatFrame:GetName() or "?", tostring(err))
    end
end

-- Each window's own saved background.
local function restore(chatFrame)
    local _, _, r, g, b, a = FCF_GetChatWindowInfo(chatFrame:GetID())
    if r and g and b then
        paint(chatFrame, r, g, b, a or DEFAULT_CHATFRAME_ALPHA)
    end
end

local function forEachChatFrame(func)
    for _, name in ipairs(CHAT_FRAMES) do
        local chatFrame = _G[name]
        if chatFrame then
            func(chatFrame)
        end
    end
end

---@return SeamlessChat.BackgroundSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.BackgroundSettings]]
end

function module:Paint(chatFrame)
    local color = self:Settings().color
    paint(chatFrame, color.r, color.g, color.b, color.a)
end

function module:OnInitialize()
    local function onSet(chatFrame)
        if not painting and self:IsEnabled() and chatFrame then
            self:Paint(chatFrame)
        end
    end
    hooksecurefunc("FCF_SetWindowColor", onSet)
    hooksecurefunc("FCF_SetWindowAlpha", onSet)
end

function module:OnEnable()
    forEachChatFrame(function(chatFrame)
        self:Paint(chatFrame)
    end)
end

function module:OnDisable()
    forEachChatFrame(restore)
end

function module:Refresh()
    if self:IsEnabled() then
        self:OnEnable()
    end
end

function module:GetOptions()
    return {
        color = {
            type = "color",
            order = 10,
            name = L["Background"],
            desc = L["Color and opacity of every chat window's background. Opacity 0 hides it; the game shows it at least at 25% while the mouse is over the chat."],
            hasAlpha = true,
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b, color.a
            end,
            set = function(_, r, g, b, a)
                local color = self:Settings().color
                color.r, color.g, color.b, color.a = r, g, b, a
                self:Refresh()
            end,
        },
        reset = {
            type = "execute",
            order = 20,
            name = L["Black"],
            desc = L["Back to black, fully opaque."],
            func = function()
                local color = self:Settings().color
                color.r, color.g, color.b, color.a = 0, 0, 0, 1
                self:Refresh()
                app.options:Refresh()
            end,
        },
    }
end
