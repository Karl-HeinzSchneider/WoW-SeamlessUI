---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.QuestLogSummary
---@field totalQuests integer
---@field completedQuests integer Quests currently ready to turn in.
---@field completedQuestXP number Total XP reported by the client for completed quests.

-- Returns a fresh snapshot; callers can refresh on QUEST_LOG_UPDATE.
-- Reading by quest ID leaves the player's quest selection and collapsed headers unchanged.
---@return SeamlessCore.QuestLogSummary
function app.addon:GetQuestLogSummary()
    local summary = { totalQuests = 0, completedQuests = 0, completedQuestXP = 0 }

    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader then
            summary.totalQuests = summary.totalQuests + 1
            if C_QuestLog.IsComplete(info.questID) then
                summary.completedQuests = summary.completedQuests + 1
                summary.completedQuestXP = summary.completedQuestXP + (GetQuestLogRewardXP(info.questID) or 0)
            end
        end
    end

    return summary
end
