---@type string, SeamlessChat
local appName, app = ...

local log = app.logger

---@class SeamlessChat.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0
---@field db SeamlessChat.DB
local addon = {}
LibStub("AceAddon-3.0"):NewAddon(addon, appName, "AceConsole-3.0", "AceEvent-3.0")
app.addon = addon

-- Called once, after ADDON_LOADED for this addon: SavedVariables are available now.
function addon:OnInitialize()
    local db = LibStub("AceDB-3.0"):New("SeamlessChatDB", app.dbDefaults, true) --[[@as SeamlessChat.DB]]
    self.db = db
    app.db = db

    db.RegisterCallback(self, "OnProfileChanged", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileCopied", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileReset", "OnProfileRefresh")

    self:RegisterChatCommand("seamlesschat", "OnSlashCommand")

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
        log:chat("Profile reset")
    elseif cmd == "save" then
        if app.sync:Save(true) then
            log:chat("Saved this character's chat; your other characters get it at their next login.")
        else
            log:chat("The chat hasn't loaded yet, try again in a moment.")
        end
    elseif cmd == "apply" then
        app.sync:Apply()
    elseif cmd == "log" then
        SeamlessChatLogWindow:Toggle()
    elseif cmd == "search" then
        -- Everything after "search", spaces included.
        app.chatLog:Search(input:match("^%s*%S+%s*(.-)%s*$") or "")
    else
        log:chat(
            "Commands: /seamlesschat [options], /seamlesschat log, /seamlesschat search <text>, /seamlesschat save, /seamlesschat apply, /seamlesschat loglevel <level>, /seamlesschat reset"
        )
    end
end
