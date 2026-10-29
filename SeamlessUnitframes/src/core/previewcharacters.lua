---@type string, SeamlessUnitframes
local _, app = ...

-- Native previews change cosmetics only; unit identity and protected frame state stay native.
local nativeFrames = { player = "PlayerFrame", pet = "PetFrame", target = "TargetFrame", focus = "FocusFrame" }
---@class SeamlessUnitframes.PreviewCharacters : AceModule
local module = {}
app.previewCharacters = app.addon:NewModule("PreviewCharacters", module)

function module:Get(frame, key)
    local native = nativeFrames[key]
    if native then
        if frame == nil or frame ~= _G[native] then
            return nil
        end
    elseif (key ~= "targettarget" and key ~= "focustarget") or frame == nil or frame ~= app.totMover.movers[key] then
        return nil
    end
    if not self:IsEnabled() or not app.addon:IsEnabled() then
        return nil
    end
    return app.core:GetPreviewCharacter("unitframes:" .. key)
end

function module:Refresh()
    app.totMover:Refresh()
    -- Only our visual modules run here, never the native full unit-frame updater.
    app.nameDisplay:Refresh()
    app.classIcon:Refresh()
    app.healthColor:Refresh()
end

function module:OnInitialize()
    local lib = app.core:GetEditModeLibrary()
    lib:RegisterCallback("enter", function()
        self:Refresh()
    end)
    lib:RegisterCallback("exit", function()
        self:Refresh()
    end)
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
