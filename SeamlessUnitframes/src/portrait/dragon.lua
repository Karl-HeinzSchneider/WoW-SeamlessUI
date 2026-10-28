---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.PortraitDragon : AceModule, AceEvent-3.0
local module = {}
app.portraitDragon = app.addon:NewModule("PortraitDragon", module, "AceEvent-3.0")

local texture
local prefix = "UI-HUD-UnitFrame-Target-PortraitOn-"
-- Fixed offsets relative to the target portrait's TOPRIGHT (-26, -19).
-- Mirroring both the art and anchor puts the dragon on the player's outer edge.
local current = {
    elite = { "Boss-Gold", 26, 20 },
    rare = { "Boss-Rare-Silver-Winged", 34, 12 },
    boss = { "Boss-Gold-Winged", 37, 15 },
}
local legacy = {
    elite = { "Boss-Gold", 15, 11 },
    rare = { "Boss-Rare-Silver", 15, 11 },
    boss = { "Boss-Gold-Winged", 34, 11 },
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
    local atlas = prefix .. definition[1]
    if old then
        local data = app.legacyAtlases[atlas:lower()]
        texture:SetTexture("Interface/HUD/UIUnitFrameBoss2x")
        texture:SetSize(data[2], data[3])
        texture:SetTexCoord(data[5], data[4], data[6], data[7])
    else
        local data = C_Texture.GetAtlasInfo(atlas)
        if not data then
            texture:Hide()
            return
        end
        texture:SetAtlas(atlas, true)
        texture:SetTexCoord(data.rightTexCoord, data.leftTexCoord, data.topTexCoord, data.bottomTexCoord)
    end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame.portrait, "TOPLEFT", -definition[2], definition[3])
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
