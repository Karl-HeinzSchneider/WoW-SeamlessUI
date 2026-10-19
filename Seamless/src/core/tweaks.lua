---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.Tweaks : AceModule, AceConsole-3.0
---@field active? boolean
local module = {}
app.tweaks = app.addon:NewModule("Tweaks", module, "AceConsole-3.0") --[[@as SeamlessCore.Tweaks]]

local lib = app.addon:GetEditModeLibrary()
local visibilityBeforeEditMode

local function PreviewFramerate()
    if not app.tweaks.active or not FramerateFrame then
        return
    end
    if visibilityBeforeEditMode == nil then
        visibilityBeforeEditMode = FramerateFrame:IsShown()
    end
    FramerateFrame:Show()
end

local function RestoreFramerate()
    if visibilityBeforeEditMode ~= nil then
        FramerateFrame:SetShown(visibilityBeforeEditMode)
        visibilityBeforeEditMode = nil
    end
end

app.addon:RegisterEditModeOptions("Seamless.Framerate", {
    section = "options",
    enabled = function()
        return app.db and app.tweaks.active
    end,
    options = {
        {
            key = "showFramerateOnStartup",
            type = "toggle",
            name = "Show FPS on startup",
            get = function()
                return app.db.profile.tweaks.showFramerateOnStartup
            end,
            set = function(value)
                app.db.profile.tweaks.showFramerateOnStartup = value
            end,
        },
    },
})

lib:RegisterCallback("enter", PreviewFramerate)
lib:RegisterCallback("exit", RestoreFramerate)

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
    if lib:IsInEditMode() then
        PreviewFramerate()
    end
    app.addon:RefreshEditModeOptions()
end

function module:OnDisable()
    RestoreFramerate()
    self.active = false
    self:OnProfileRefresh()
    app.addon:RefreshEditModeOptions()
end
