---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.PortraitDragon : AceModule, AceEvent-3.0
local module = {}
app.portraitDragon = app.addon:NewModule("PortraitDragon", module, "AceEvent-3.0")

local texture
-- Fixed 70425 atlas records from docs/atlas/AtlasInfo.1.60.1.70425.json.
-- Keep each sheet, crop and logical size together: runtime atlas selection can
-- choose a different atlas set from the one described by GetAtlasInfo.
-- Offsets mirror the native target decoration around its portrait (-26, -19).
local current = {
    elite = { 100.0, 100.0, 0.001953125, 0.392578125, 0.001953125, 0.392578125, 26, 20 },
    rare = { 109.0, 88.5, 0.435546875, 0.861328125, 0.396484375, 0.7421875, 34, 12 },
    boss = { 110.0, 90.0, 0.001953125, 0.431640625, 0.396484375, 0.748046875, 37, 15 },
}
local legacy = {
    elite = { 80.0, 79.0, 0.001953125, 0.314453125, 0.322265625, 0.630859375, 15, 11 },
    rare = { 80.0, 79.0, 0.001953125, 0.314453125, 0.634765625, 0.943359375, 15, 11 },
    boss = { 99.0, 81.0, 0.001953125, 0.388671875, 0.001953125, 0.318359375, 34, 11 },
}

function module:Refresh()
    local old = app.db.profile.layout == "legacy"
    local definition = (old and legacy or current)[app.db.profile.unitFrames.player.portraitDragon]
    if not app.addon:IsEnabled() or not self:IsEnabled() or not definition then
        if texture then
            texture:Hide()
        end
        return
    end
    if InCombatLockdown() then
        return
    end
    local frame = PlayerFrame
    if not app.legacyLayout:CheckPaths(frame, "Player portrait dragon", { "PlayerFrameContainer", "portrait" }) then
        return
    end
    if not texture then
        texture = frame.PlayerFrameContainer:CreateTexture(nil, "OVERLAY", nil, 1)
    end
    texture:SetTexture(old and "Interface/HUD/UIUnitFrameBoss2x" or "Interface/HUD/UIUnitFrameBossC602x")
    texture:SetSize(definition[1], definition[2])
    texture:SetTexCoord(definition[4], definition[3], definition[5], definition[6])
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame.portrait, "TOPLEFT", -definition[7], definition[8])
    texture:Show()
end

function module:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    if not self.hooked then
        self.hooked = true
        hooksecurefunc(app.legacyLayout, "Refresh", function()
            self:Refresh()
        end)
    end
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

function module:OnProfileRefresh()
    self:Refresh()
end
