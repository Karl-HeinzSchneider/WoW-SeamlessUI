---@type string, SeamlessCore
local _, app = ...

local log = app.logger

---@class SeamlessCore.Tweaks : AceModule, AceConsole-3.0
---@field active? boolean
local module = {}
app.tweaks = app.addon:NewModule("Tweaks", module, "AceConsole-3.0") --[[@as SeamlessCore.Tweaks]]

local function reload()
    ReloadUI()
end

-- Same as the Keybindings settings' Quick Keybind Mode button; the frame is protected.
local function quickKeybind()
    if InCombatLockdown() then
        log:warn(ERR_NOT_IN_COMBAT)
        return
    end
    if not QuickKeybindFrame then
        return
    end
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsPanel:Close(true)
    end
    QuickKeybindFrame:Show()
end

---@param command string
---@param handler function
---@param enabled boolean
function module:SetShortcut(command, handler, enabled)
    local key = "ACECONSOLE_" .. command:upper()
    if self.active and enabled then
        if SlashCmdList[key] ~= handler then
            self:RegisterChatCommand(command, handler)
        end
    elseif SlashCmdList[key] == handler then
        -- Another addon may have replaced this command since we registered it.
        self:UnregisterChatCommand(command)
    end
end

function module:OnProfileRefresh()
    local tweaks = app.db.profile.tweaks
    self:SetShortcut("rl", reload, tweaks.reloadShortcut)
    self:SetShortcut("kb", quickKeybind, tweaks.quickKeybindShortcut)
end

function module:OnEnable()
    self.active = true
    self:OnProfileRefresh()
    -- Apply only at startup so normal framerate keybinds remain in control afterward.
    if app.db.profile.tweaks.showFramerateOnStartup then
        FramerateFrame:Show()
    end
end

function module:OnDisable()
    self.active = false
    self:OnProfileRefresh()
end
