---@type string, SeamlessTooltip
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local log = app.logger

---@class SeamlessTooltip.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0
---@field db SeamlessTooltip.DB
local addon = {}
LibStub("AceAddon-3.0"):NewAddon(addon, appName, "AceConsole-3.0", "AceEvent-3.0")
app.addon = addon

-- Called once, after ADDON_LOADED for this addon: SavedVariables are available now.
function addon:OnInitialize()
    local db = LibStub("AceDB-3.0"):New("SeamlessTooltipDB", app.dbDefaults, true) --[[@as SeamlessTooltip.DB]]
    self.db = db
    app.db = db

    db.RegisterCallback(self, "OnProfileChanged", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileCopied", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileReset", "OnProfileRefresh")

    self:RegisterChatCommand("seamlesstooltip", "OnSlashCommand")

    self:OnProfileRefresh()
    log:debug(L["Initialized (profile: %s)"], db:GetCurrentProfile())
end

-- Called after OnInitialize and whenever the addon is re-enabled. Register events here.
function addon:OnEnable()
    log:debug(L["Enabled"])
end

-- Ace unregisters events/timers/hooks automatically on disable.
function addon:OnDisable()
    log:debug(L["Disabled"])
end

-- Re-apply everything that depends on profile settings. Modules opt in by defining OnProfileRefresh.
function addon:OnProfileRefresh()
    for _, module in self:IterateModules() do
        if module.OnProfileRefresh then
            module:OnProfileRefresh()
        end
    end
end

---@param input string
function addon:OnSlashCommand(input)
    local cmd = self:GetArgs(input, 1)
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "options" then
        app.options:Open()
    elseif cmd == "loglevel" then
        app.core:OnSlashCommand(input)
    elseif cmd == "reset" then
        self.db:ResetProfile()
        log:chat(L["Profile reset"])
    else
        log:chat(L["Commands: /seamlesstooltip [options], /seamlesstooltip loglevel <level>, /seamlesstooltip reset"])
    end
end
