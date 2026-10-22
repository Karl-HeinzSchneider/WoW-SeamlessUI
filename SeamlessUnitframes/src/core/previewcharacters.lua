---@type string, SeamlessUnitframes
local _, app = ...

-- Only addon-owned ToT stand-ins consume VIP records. Never hook or refresh native units here.
---@class SeamlessUnitframes.PreviewCharacters : AceModule
local module = {}
app.previewCharacters = app.addon:NewModule("PreviewCharacters", module)

function module:Get(frame, key)
    if key ~= "targettarget" and key ~= "focustarget" then
        return nil
    end
    if frame ~= app.totMover.movers[key] or frame == nil then
        return nil
    end
    if not self:IsEnabled() or not app.addon:IsEnabled() then
        return nil
    end
    return app.core:GetPreviewCharacter("unitframes:" .. key)
end

function module:Refresh()
    app.totMover:Refresh()
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
