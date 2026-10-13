---@type string, SeamlessChat
local _, app = ...

-- Fade-out control: whether chat messages fade out after a while, how long they stay, and how long
-- the fade takes. Applies to every chat window (temporary ones too); the game's values come back
-- when disabled.
---@class SeamlessChat.Fading : SeamlessChat.Feature
local module = { optionsTab = "windows" }

---@class SeamlessChat.FadingSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    fade = true, -- messages fade out at all
    timeVisible = 120, -- seconds a message stays before fading (the game's value)
    fadeDuration = 3, -- seconds the fade takes (the game's value)
}

app.features:New(
    "fading",
    module,
    "Fade-out",
    "Whether chat messages fade out after a while, how long they stay, and how long the fade takes.",
    defaults
)

-- What the game's chat windows use (ChatFrameMixin:OnLoad, ScrollingMessageFrameMixin:OnPreLoad).
local BLIZZARD = { fade = true, timeVisible = 120, fadeDuration = 3 }

---@param values { fade: boolean, timeVisible: number, fadeDuration: number }
local function apply(values)
    for _, name in ipairs(CHAT_FRAMES) do
        local chatFrame = _G[name]
        if chatFrame and chatFrame.SetFading then
            chatFrame:SetFading(values.fade)
            chatFrame:SetTimeVisible(values.timeVisible)
            chatFrame:SetFadeDuration(values.fadeDuration)
            -- Lines already faded out come back under the new timing.
            chatFrame:ResetAllFadeTimes()
        end
    end
end

---@return SeamlessChat.FadingSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.FadingSettings]]
end

function module:OnInitialize()
    -- A new temporary (whisper) window starts with the game's values.
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        if self:IsEnabled() then
            apply(self:Settings())
        end
    end)
end

function module:OnEnable()
    apply(self:Settings())
end

function module:OnDisable()
    apply(BLIZZARD)
end

function module:Refresh()
    apply(self:Settings())
end

function module:GetOptions()
    local function fadingOff()
        local settings = self:Settings()
        return not (settings.enabled and settings.fade)
    end
    return {
        fade = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Fade out old messages",
            desc = "Off keeps every message visible.",
        },
        timeVisible = {
            type = "range",
            order = 20,
            width = "double",
            name = "Seconds visible",
            desc = "How long a message stays before it fades out. The game uses 120.",
            min = 5,
            max = 3600,
            softMax = 600,
            step = 1,
            bigStep = 5,
            disabled = fadingOff,
        },
        fadeDuration = {
            type = "range",
            order = 30,
            width = "double",
            name = "Fade duration",
            desc = "How many seconds the fade itself takes. The game uses 3.",
            min = 0,
            max = 10,
            step = 0.5,
            disabled = fadingOff,
        },
    }
end
