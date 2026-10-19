---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.Tweaks : AceModule, AceConsole-3.0
---@field active? boolean
local module = {}
app.tweaks = app.addon:NewModule("Tweaks", module, "AceConsole-3.0") --[[@as SeamlessCore.Tweaks]]

local function reload()
    ReloadUI()
end

function module:OnProfileRefresh()
    if self.active and app.db.profile.tweaks.reloadShortcut then
        if SlashCmdList.ACECONSOLE_RL ~= reload then
            self:RegisterChatCommand("rl", reload)
        end
    elseif SlashCmdList.ACECONSOLE_RL == reload then
        -- Another addon may have replaced this command since we registered it.
        self:UnregisterChatCommand("rl")
    end
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
