---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.TargetQuestIcon : AceModule, AceEvent-3.0
---@field frame? Frame
---@field active? boolean
local module = {}
app.targetQuestIcon = app.addon:NewModule("TargetQuestIcon", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.TargetQuestIcon]]

function module:Update()
    if self.frame then
        local key = self.active and app.db.profile.targetQuestIcon.enabled and app.questIcons:ForUnit("target")
        app.questIcons:SetIcon(self.frame, key or nil)
    end
end

function module:ApplyLayout()
    if not self.frame then
        return
    end
    local db = app.db.profile.targetQuestIcon
    self.frame:SetSize(16 * db.scale, 16 * db.scale)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("RIGHT", TargetFrame, "RIGHT", db.x, db.y)
end

function module:OnProfileRefresh()
    if self.active and app.db.profile.targetQuestIcon.enabled and TargetFrame then
        if not self.frame then
            self.frame = app.questIcons:CreateFrame(TargetFrame)
        end
        self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
        self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "Update")
        self:RegisterEvent("QUEST_LOG_UPDATE", "Update")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
        self:ApplyLayout()
    else
        self:UnregisterAllEvents()
    end
    self:Update()
end

function module:OnEnable()
    self.active = true
    self:OnProfileRefresh()
end

function module:OnDisable()
    self.active = false
    self:OnProfileRefresh()
end
