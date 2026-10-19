---@type string, SeamlessDamageMeter
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local addon = app.addon

function addon:OnInitialize()
    app.db = LibStub("AceDB-3.0"):New("SeamlessDamageMeterDB", {
        char = {},
        profile = {
            windows = {},
            initialized = false,
            locked = false,
            hideBlizzard = true,
            windowDefaults = app.windowDefaults,
            favorites = {},
            maxVisibleFavorites = 6,
        },
    }, true)
    app.combatService:Initialize(app.db.char)
    app.combatService:Subscribe(app, function(owner, historyChanged)
        owner:RefreshWindows()
        if historyChanged then
            owner.core:RefreshOptions(appName)
        end
    end)
    app.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    app.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    app.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")
    self:RegisterChatCommand("seamlessdamagemeter", "SlashCommand")
    self:RegisterChatCommand("sdm", "SlashCommand")
    app:RegisterOptions()
end

function addon:RefreshProfile()
    app:ApplyEditModeLayout()
    app:RebuildWindows()
    app:UpdateBlizzardMeter()
    app.core:RefreshOptions(appName)
end

function addon:OnEnable()
    self:RefreshProfile()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        app.combatService:OnWorld()
    end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        app.combatService:OnWorld()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        app.combatService:OnCombatEnd()
        self:RefreshProfile()
    end)
    self:RegisterEvent("PLAYER_LOGOUT", function()
        app.combatService:OnLogout()
    end)
    self:RegisterEvent("ENCOUNTER_START", function(event, ...)
        app.combatService:OnEncounter(event, ...)
    end)
    self:RegisterEvent("ENCOUNTER_END", function(event, ...)
        app.combatService:OnEncounter(event, ...)
    end)
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "damagemeterenabled" then
            app.combatService:OnWorld()
            self:RefreshData()
            app.core:RefreshOptions(appName)
        end
    end)
    for _, event in ipairs({
        "UNIT_THREAT_LIST_UPDATE",
        "UNIT_THREAT_SITUATION_UPDATE",
        "PLAYER_TARGET_CHANGED",
        "GROUP_ROSTER_UPDATE",
        "UNIT_PET",
        "UNIT_TARGET",
        "PLAYER_FOCUS_CHANGED",
        "UPDATE_MOUSEOVER_UNIT",
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "UNIT_NAME_UPDATE",
        "UNIT_FACTION",
    }) do
        self:RegisterEvent(event, function()
            app:RefreshThreatWindows()
        end)
    end
    if app:IsAvailable() then
        for _, event in ipairs({
            "DAMAGE_METER_COMBAT_SESSION_UPDATED",
            "DAMAGE_METER_CURRENT_SESSION_UPDATED",
            "DAMAGE_METER_RESET",
        }) do
            self:RegisterEvent(event, function(name, ...)
                app.combatService:OnMeterEvent(name, ...)
            end)
        end
    end
    -- Also refresh rates while a session is active, with one timer for all windows.
    self:ScheduleRepeatingTimer("RefreshData", 0.5)
    self:ScheduleRepeatingTimer(function()
        app.combatService:Tick()
    end, 0.2)
    app.combatService:OnWorld()
end

function addon:RefreshData()
    app:RefreshWindows(true)
end

function addon:OnDisable()
    self:CancelAllTimers()
    self:UnregisterAllEvents()
    app:HideWindows()
    app:UpdateBlizzardMeter()
end

function addon:SlashCommand(input)
    local command = (self:GetArgs(input, 1) or ""):lower()
    if command == "new" then
        app:AddWindow()
    elseif command == "show" then
        for _, config in ipairs(app.db.profile.windows) do
            config.hidden = false
        end
        self:RefreshProfile()
    elseif command == "" or command == "options" then
        app.core:OpenOptions(appName)
    else
        app.core.logger:chat("/sdm [options], /sdm new, /sdm show. Use each window's menu to deactivate it.")
    end
end
