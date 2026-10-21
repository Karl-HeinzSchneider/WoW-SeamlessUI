---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Unread counts: a docked chat tab that isn't selected shows how many messages came in since it
-- was last looked at, as a badge on the tab's corner. Selecting the tab clears it.
--
-- Counted from the line wrapper (src/chat/lines.lua) as an observer that never changes the line,
-- so it sees exactly what reaches each window. Only chat messages count (lines with a chat type),
-- not print() and other addon output. The badge sits on UIParent beside the tab rather than on the
-- tab itself: the game fades idle tabs out, and the count should stay readable.
---@class SeamlessChat.Unread : SeamlessChat.Feature
---@field counts table<Frame, integer> unread messages by chat window
---@field badges table<Frame, Frame> the badge of each chat window's tab
local module = { optionsTab = "windows" }

---@class SeamlessChat.UnreadSettings : SeamlessChat.FeatureSettings
local feature = app.features:New(
    "unread",
    module,
    L["Unread counts"],
    L["Shows how many messages came in on a chat tab while another tab was selected, as a badge on its corner. Selecting the tab clears it."]
) --[[@as SeamlessChat.Unread]]

-- Before the other transforms; it only counts.
local ORDER = 1
local MAX_SHOWN = 99
local BADGE_HEIGHT = 14

---@return SeamlessChat.UnreadSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.UnreadSettings]]
end

-- The docked window currently shown, whose messages are read as they come.
local function selectedWindow()
    if GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow then
        return FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    end
end

local function tabOf(chatFrame)
    local name = chatFrame:GetName()
    return name and _G[name .. "Tab"]
end

-- Badge -------------------------------------------------------------------------------------------

function module:CreateBadge(chatFrame, tab)
    local badge = CreateFrame("Frame", nil, UIParent)
    badge:SetFrameStrata(tab:GetFrameStrata())
    badge:SetFrameLevel(tab:GetFrameLevel() + 5)
    badge:SetHeight(BADGE_HEIGHT)
    badge:SetPoint("CENTER", tab, "TOPRIGHT", -6, -4)
    badge.fill = badge:CreateTexture(nil, "BACKGROUND")
    badge.fill:SetAllPoints()
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.text:SetPoint("CENTER", 0, 0)
    badge:Hide()
    -- The tab hides when its window is closed or scrolled into the dock's overflow; the badge too.
    tab:HookScript("OnShow", function()
        self:UpdateBadge(chatFrame)
    end)
    tab:HookScript("OnHide", function()
        badge:Hide()
    end)
    self.badges[chatFrame] = badge
    return badge
end

function module:UpdateBadge(chatFrame)
    local count = self.counts[chatFrame] or 0
    local badge = self.badges[chatFrame]
    local tab = tabOf(chatFrame)
    if not (self:IsEnabled() and count > 0 and tab and tab:IsShown()) then
        if badge then
            badge:Hide()
        end
        return
    end
    badge = badge or self:CreateBadge(chatFrame, tab)
    local color = self:Settings().color
    badge.fill:SetColorTexture(color.r, color.g, color.b, 0.9)
    badge.text:SetText(count > MAX_SHOWN and MAX_SHOWN .. "+" or tostring(count))
    badge:SetWidth(math.max(BADGE_HEIGHT, badge.text:GetStringWidth() + 6))
    badge:Show()
end

function module:Clear(chatFrame)
    if self.counts[chatFrame] then
        self.counts[chatFrame] = nil
        self:UpdateBadge(chatFrame)
    end
end

function module:ClearAll()
    for chatFrame in pairs(self.counts) do
        self.counts[chatFrame] = nil
        self:UpdateBadge(chatFrame)
    end
end

-- Counting ----------------------------------------------------------------------------------------

---@param chatFrame Frame
---@param chatType string?
function module:Count(chatFrame, chatType)
    if not (self:IsEnabled() and chatType) then
        return
    end
    if chatType == "CHANNEL" and not self:Settings().channels then
        return
    end
    -- A window of its own (not docked) is always in view, and the selected one is being read.
    if not chatFrame.isDocked or chatFrame == selectedWindow() then
        return
    end
    self.counts[chatFrame] = (self.counts[chatFrame] or 0) + 1
    self:UpdateBadge(chatFrame)
end

-- Lifecycle --------------------------------------------------------------------------------------

function module:OnInitialize()
    self.counts = {}
    self.badges = {}
    -- Secret lines count too: the line itself is never touched.
    app.lines:Register(ORDER, function(chatFrame, message, chatType)
        feature:Count(chatFrame, chatType)
        return message
    end, true)
    hooksecurefunc("FCFDock_SelectWindow", function(_, chatFrame)
        if chatFrame then
            self:Clear(chatFrame)
        end
    end)
    -- An undocked window is in view, a closed one gone.
    hooksecurefunc("FCF_UnDockFrame", function(chatFrame)
        self:Clear(chatFrame)
    end)
    hooksecurefunc("FCF_Close", function(chatFrame)
        if chatFrame then
            self:Clear(chatFrame)
        end
    end)
end

function module:OnDisable()
    self:ClearAll()
end

function module:Refresh()
    for chatFrame in pairs(self.counts) do
        self:UpdateBadge(chatFrame)
    end
end

function module:GetOptions()
    return {
        channels = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Count channel messages"],
            desc = L["Messages in numbered channels such as General and Trade count too."],
        },
        color = {
            type = "color",
            order = 20,
            name = L["Badge color"],
            desc = L["The background of the unread count."],
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().color
                color.r, color.g, color.b = r, g, b
                self:Refresh()
            end,
        },
    }
end
