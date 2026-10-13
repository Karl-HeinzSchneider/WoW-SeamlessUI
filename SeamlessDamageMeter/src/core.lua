---@type string, SeamlessDamageMeter
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("SeamlessCore")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local addon = app.addon

function addon:OnInitialize()
    app.db = LibStub("AceDB-3.0"):New("SeamlessDamageMeterDB", {
        profile = {
            windows = {},
            initialized = false,
            locked = false,
            hideBlizzard = true,
            windowDefaults = app.windowDefaults,
        },
    }, true)
    app.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    app.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    app.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")
    self:RegisterChatCommand("seamlessdamagemeter", "SlashCommand")
    self:RegisterChatCommand("sdm", "SlashCommand")
    app:RegisterOptions()
end

function addon:RefreshProfile()
    app:RebuildWindows()
    app:UpdateBlizzardMeter()
    app.core:RefreshOptions(appName)
end

function addon:OnEnable()
    app:EnsureTracking()
    self:RefreshProfile()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshData")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshProfile")
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "damagemeterenabled" then
            self:RefreshData()
            app.core:RefreshOptions(appName)
        end
    end)
    if app:IsAvailable() then
        self:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", "RefreshData")
        self:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", "RefreshData")
        self:RegisterEvent("DAMAGE_METER_RESET", "RefreshData")
    end
    -- Also refresh rates while a session is active, with one timer for all windows.
    self:ScheduleRepeatingTimer("RefreshData", 0.5)
end

function addon:RefreshData()
    app:RefreshWindows()
end

function addon:OnDisable()
    self:CancelAllTimers()
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
