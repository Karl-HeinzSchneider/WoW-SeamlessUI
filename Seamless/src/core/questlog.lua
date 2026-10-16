---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.QuestLog : AceModule, AceEvent-3.0
---@field text? FontString
---@field active? boolean
local module = {}
app.addon:NewModule("QuestLog", module, "AceEvent-3.0")

function module:Refresh()
    if not self.active then
        return
    end

    local frame = WorldMapFrame
    local border = frame and frame.BorderFrame
    local minimize = border and border.MaximizeMinimizeFrame
    local title = border and border.TitleContainer
    if not minimize or not title then
        return
    end

    if not self.text then
        -- The border's NineSlice covers font strings on the border itself.
        -- Use the title's higher frame level while anchoring beside the button.
        self.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.text:SetPoint("RIGHT", minimize, "LEFT", -8, 0)
        self.text:SetJustifyH("RIGHT")
        frame:HookScript("OnShow", function()
            self:Refresh()
        end)
    end

    local summary = app.addon:GetQuestLogSummary()
    self.text:SetFormattedText(
        "Completed: %d  |  %s XP",
        summary.completedQuests,
        BreakUpLargeNumbers(summary.completedQuestXP)
    )
    self.text:Show()
end

function module:OnEnable()
    self.active = true
    self:RegisterEvent("ADDON_LOADED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("QUEST_LOG_UPDATE", "Refresh")
    self:RegisterEvent("QUEST_DATA_LOAD_RESULT", "Refresh")
    self:RegisterEvent("PLAYER_LEVEL_UP", "Refresh")
    self:Refresh()
end

function module:OnDisable()
    self.active = false
    if self.text then
        self.text:Hide()
    end
end
