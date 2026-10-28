---@type string, SeamlessUnitframes
local _, app = ...

-- Only exact addon-owned stand-ins/overlays consume VIP records.
---@class SeamlessUnitframes.PreviewCharacters : AceModule
local module = {}
app.previewCharacters = app.addon:NewModule("PreviewCharacters", module)

function module:Get(frame, key)
    local owned = (key == "targettarget" or key == "focustarget") and app.totMover.movers[key]
        or app.previewOverlays and app.previewOverlays.frames[key]
    if frame ~= owned or frame == nil then
        return nil
    end
    if not self:IsEnabled() or not app.addon:IsEnabled() then
        return nil
    end
    return app.core:GetPreviewCharacter("unitframes:" .. key)
end

function module:Refresh()
    app.totMover:Refresh()
    if app.previewOverlays then
        app.previewOverlays:Refresh()
    end
end

function module:OnInitialize()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        self:Refresh()
    end)
end

module.OnEnable = module.Refresh
module.OnDisable = module.Refresh
module.OnProfileRefresh = module.Refresh
