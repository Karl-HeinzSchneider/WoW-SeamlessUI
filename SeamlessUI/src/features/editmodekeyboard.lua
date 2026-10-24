---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
---@class SeamlessUI.EditModeKeyboard : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("EditModeKeyboard", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.EditModeKeyboard]]
app.editModeKeyboard = module

local consumedKeys = { LEFT = true, RIGHT = true, UP = true, DOWN = true, ESCAPE = true, PRINTSCREEN = true }

-- Keep Blizzard's handlers, including Shift and key-up bookkeeping.
function module:OnKey(dialog, key)
    if not InCombatLockdown() then
        dialog:SetPropagateKeyboardInput(app.db.profile.editModeKeyboard and not consumedKeys[key] or false)
    end
end

function module:InstallHooks()
    local dialog = EditModeSystemSettingsDialog
    if dialog and not self:IsHooked(dialog, "OnKeyDown") then
        self:SecureHookScript(dialog, "OnKeyDown", "OnKey")
        self:SecureHookScript(dialog, "OnKeyUp", "OnKey")
    end
end

-- A disabled option/module must restore native capture, including after a profile switch.
-- Defer restoration if the addon is disabled during combat.
local restore = CreateFrame("Frame")
local function RestoreCapture()
    if InCombatLockdown() then
        restore:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        restore:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if EditModeSystemSettingsDialog then
            EditModeSystemSettingsDialog:SetPropagateKeyboardInput(false)
        end
    end
end
restore:SetScript("OnEvent", RestoreCapture)

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:InstallHooks()
end

function module:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    RestoreCapture()
end

function module:OnProfileRefresh()
    RestoreCapture()
end

function module:Options()
    return {
        type = "toggle",
        order = 30,
        width = "full",
        name = L["Pass unused Edit Mode keys through"],
        desc = L["Let normal key bindings work while a Blizzard frame is selected in Edit Mode. Arrow adjustments, Shift, Escape and screenshots keep their normal behavior."],
        get = function()
            return app.db.profile.editModeKeyboard
        end,
        set = function(_, value)
            app.db.profile.editModeKeyboard = value
            module:OnProfileRefresh()
        end,
    }
end
