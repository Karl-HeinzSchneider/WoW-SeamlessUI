---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Fade-out control: whether chat messages fade out after a while, how long they stay, and how long
-- the fade takes. Applies to every chat window (temporary ones too); the game's values come back
-- when disabled.
---@class SeamlessChat.Fading : SeamlessChat.Feature
local module = {}

---@class SeamlessChat.FadingSettings : SeamlessChat.FeatureSettings
app.features:New("fading", module)

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
