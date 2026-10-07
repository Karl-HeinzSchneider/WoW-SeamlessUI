---@type string, SeamlessCore
local appName, app = ...

local log = app.logger

---@class SeamlessCore.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0
---@field db SeamlessCore.DB
local addon = {}
LibStub("AceAddon-3.0"):NewAddon(addon, appName, "AceConsole-3.0", "AceEvent-3.0")
app.addon = addon

-- Called once, after ADDON_LOADED for this addon: SavedVariables are available now.
function addon:OnInitialize()
    local db = LibStub("AceDB-3.0"):New("SeamlessCoreDB", app.dbDefaults, true) --[[@as SeamlessCore.DB]]
    self.db = db
    app.db = db

    db.RegisterCallback(self, "OnProfileChanged", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileCopied", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileReset", "OnProfileRefresh")

    self:RegisterChatCommand("seamless", "OnSlashCommand")

    self:OnProfileRefresh()
    log:debug("Initialized (profile: %s)", db:GetCurrentProfile())
end

-- Called after OnInitialize and whenever the addon is re-enabled. Register events here.
function addon:OnEnable()
    log:debug("Enabled")
end

-- Ace unregisters events/timers/hooks automatically on disable.
function addon:OnDisable()
    log:debug("Disabled")
end

-- Re-apply everything that depends on profile settings. Modules opt in by defining OnProfileRefresh.
function addon:OnProfileRefresh()
    log:setLevel(self.db.profile.logLevel)
    for _, module in self:IterateModules() do
        if module.OnProfileRefresh then
            module:OnProfileRefresh()
        end
    end
end

---@param input string
function addon:OnSlashCommand(input)
    local cmd, arg = self:GetArgs(input, 2)
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "options" then
        app.options:Open()
    elseif cmd == "loglevel" then
        if arg and log:setLevel(arg) then
            self.db.profile.logLevel = log:getLevelName()
            log:chat("Log level set to %s", self.db.profile.logLevel)
            app.options:Refresh()
        else
            log:chat("Log level is %s", log:getLevelName())
        end
    elseif cmd == "reset" then
        self.db:ResetProfile()
        log:chat("Profile reset")
    else
        log:chat("Commands: /seamless [options], /seamless loglevel <level>, /seamless reset")
    end
end

-- Available at file load to dependent addons through AceAddon:GetAddon("SeamlessCore").
addon.logger = app.logger

---@param name string
---@param title string
---@param build fun(panel: SeamlessCore.SettingsPanel)
---@return SeamlessCore.SettingsPanel
function addon:RegisterOptions(name, title, build)
    return app.options:RegisterAddon(name, title, build)
end

---@param name string?
function addon:OpenOptions(name)
    app.options:Open(name)
end

---@param name string?
function addon:RefreshOptions(name)
    app.options:Refresh(name)
end
