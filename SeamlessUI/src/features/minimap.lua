---@type string, SeamlessUI
local _, app = ...

---@class SeamlessUI.Minimap : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("Minimap", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.Minimap]]
app.minimap = module

function module:Apply()
    local frame = MinimapCluster and MinimapCluster.DielFrame
    if not frame then
        return
    end
    if not self:IsHooked(frame, "OnShow") then
        self:SecureHookScript(frame, "OnShow", "Apply")
    end
    if app.db.profile.hideMinimapDayNight then
        if frame:IsShown() then
            self.hiddenFrame = frame
            frame:Hide()
        end
    elseif self.hiddenFrame then
        self.hiddenFrame = nil
        frame:Show()
    end
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "Apply")
    self:Apply()
end

function module:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    if self.hiddenFrame then
        local frame = self.hiddenFrame
        self.hiddenFrame = nil
        frame:Show()
    end
end

function module:OnProfileRefresh()
    if self:IsEnabled() and IsLoggedIn() then
        self:Apply()
    end
end
