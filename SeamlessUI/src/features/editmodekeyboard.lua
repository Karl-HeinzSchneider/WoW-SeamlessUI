---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
---@class SeamlessUI.EditModeKeyboard : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("EditModeKeyboard", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.EditModeKeyboard]]
app.editModeKeyboard = module
module:SetEnabledState(false)

local consumedKeys = { LEFT = true, RIGHT = true, UP = true, DOWN = true, ESCAPE = true, PRINTSCREEN = true }

-- Keep Blizzard's handlers, including Shift and key-up bookkeeping.
function module:OnKey(dialog, key)
    if not InCombatLockdown() then
        dialog:SetPropagateKeyboardInput(not consumedKeys[key])
    end
end

function module:InstallHooks()
    local dialog = EditModeSystemSettingsDialog
    if dialog and not self:IsHooked(dialog, "OnKeyDown") then
        self:SecureHookScript(dialog, "OnKeyDown", "OnKey")
        self:SecureHookScript(dialog, "OnKeyUp", "OnKey")
        self:UnregisterEvent("ADDON_LOADED")
    end
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:InstallHooks()
end

function module:OnDisable()
    local dialog = EditModeSystemSettingsDialog
    if dialog and self:IsHooked(dialog, "OnKeyDown") and not InCombatLockdown() then
        dialog:SetPropagateKeyboardInput(false)
    end
    self:UnhookAll()
    self:UnregisterAllEvents()
end

function module:OnProfileRefresh()
    if not IsLoggedIn() then
        self:SetEnabledState(app.db.profile.editModeKeyboard)
    elseif InCombatLockdown() then
        -- Only an already active feature waits to finish a profile change after combat.
        if self:IsEnabled() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnProfileRefresh")
        end
    else
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if app.db.profile.editModeKeyboard then
            self:Enable()
        else
            self:Disable()
        end
    end
end
