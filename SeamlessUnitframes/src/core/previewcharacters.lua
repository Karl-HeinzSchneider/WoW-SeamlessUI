---@type string, SeamlessUnitframes
local _, app = ...

-- Cosmetic writes only. Never change .unit, secure attributes, events, visibility or gameplay APIs.
---@class SeamlessUnitframes.PreviewCharacters : AceModule
local module = {}
app.previewCharacters = app.addon:NewModule("PreviewCharacters", module)
local lib = app.core:GetEditModeLibrary()
local assigned, changed = {}, {}
local writing = false

local function Accessible(value)
    return not canaccessvalue or canaccessvalue(value)
end

function module:Get(frame, key)
    if not Accessible(frame) or not frame then
        return nil
    end
    if not self:IsEnabled() or not app.addon:IsEnabled() or not lib:IsInEditMode() or InCombatLockdown() then
        return nil
    end
    key = key or app.unitFrames:KeyOf(frame)
    if not key or key == "pet" then
        return nil
    end
    if not assigned[frame] then
        local id = key == "party" and frame:GetName() or key
        if Accessible(id) and type(id) == "string" then
            assigned[frame] = app.core:GetPreviewCharacter("unitframes:" .. id)
        end
    end
    return assigned[frame]
end

local function Apply(frame)
    if writing then
        return
    end
    local key = app.unitFrames:KeyOf(frame)
    local character = key and module:Get(frame, key)
    if not character then
        return
    end
    writing = true
    changed[frame] = true
    app.nameDisplay:ApplyPreview(frame, key)
    app.classIcon:ApplyPreview(frame, key)
    -- Native bars have live prediction/loss/text logic. Keep their values tied to their real
    -- units; only addon-owned stand-ins may render fabricated health and power.
    app.healthColor:ApplyPreview(frame, key)
    writing = false
end

function module:Refresh()
    if writing then
        return
    end
    if not self:IsEnabled() or not app.addon:IsEnabled() or not lib:IsInEditMode() or InCombatLockdown() then
        assigned = {}
        -- Re-read current game data, never restore a stale snapshot from before Edit Mode.
        writing = true
        for frame in pairs(changed) do
            securecall("UnitFrame_Update", frame)
        end
        changed = {}
        writing = false
        app.totMover:Refresh()
        return
    end
    for _, frame in ipairs(app.unitFrames:All()) do
        if app.unitFrames:KeyOf(frame) ~= "pet" then
            Apply(frame)
        end
    end
    app.totMover:Refresh()
end

function module:OnInitialize()
    hooksecurefunc("UnitFrame_Update", Apply)
    hooksecurefunc("UnitFramePortrait_Update", Apply)
    lib:RegisterCallback("enter", function()
        assigned = {}
        self:Refresh()
    end)
    lib:RegisterCallback("exit", function()
        self:Refresh()
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:SetScript("OnEvent", function()
        self:Refresh()
    end)
    for _, feature in ipairs({ app.nameDisplay, app.classIcon, app.healthColor, app.legacyLayout }) do
        hooksecurefunc(feature, "Refresh", function()
            self:Refresh()
        end)
    end
end

module.OnEnable = module.Refresh
module.OnDisable = module.Refresh
module.OnProfileRefresh = module.Refresh
