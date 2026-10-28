---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.LevelDisplay : AceModule, AceEvent-3.0
local module = {}
app.levelDisplay = app.addon:NewModule("LevelDisplay", module, "AceEvent-3.0")

-- Both layouts retain the client's level regions. Alpha preserves native visibility
-- (including the skull replacing the number), without showing anything the game hid.
local changed = {}

local function Apply(region, mode)
    if (canaccessvalue and not canaccessvalue(region)) or not region then
        return
    end
    if mode ~= "default" or changed[region] then
        region:SetAlpha(mode == "hidden" and 0 or 1)
        region:SetScale(mode == "smaller" and 0.7 or 1)
        changed[region] = mode ~= "default" or nil
    end
end

function module:Refresh()
    if InCombatLockdown() then
        return
    end
    for _, key in ipairs({ "player", "target", "focus" }) do
        local frame = _G[app.unitFrames:Get(key).frameName]
        local mode = app.addon:IsEnabled() and self:IsEnabled() and app.db.profile.unitFrames[key].levelDisplay
            or "default"
        if (not canaccessvalue or canaccessvalue(frame)) and frame then
            local content = key == "player" and frame.PlayerFrameContent or frame.TargetFrameContent
            local main = content
                and (key == "player" and content.PlayerFrameContentMain or content.TargetFrameContentMain)
            if main then
                Apply(main.LevelBackgroundCircle, mode)
                Apply(key == "player" and PlayerLevelText or main.LevelText, mode)
            end
            local contextual = content and content.TargetFrameContentContextual
            if contextual then
                Apply(contextual.HighLevelTexture, mode)
            end
        end
    end
end

function module:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

function module:OnProfileRefresh()
    self:Refresh()
end
