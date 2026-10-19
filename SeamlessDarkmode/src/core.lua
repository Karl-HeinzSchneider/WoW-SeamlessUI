---@type string, SeamlessDarkmode
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

app.categories = {
    {
        key = "unitframes",
        name = "Unit frames",
        roots = {
            "PlayerFrame",
            "TargetFrame",
            "FocusFrame",
            "PetFrame",
            "PartyFrame",
            "CompactRaidFrameContainer",
            "CompactPartyFrame",
            "BossTargetFrameContainer",
        },
    },
    {
        key = "actionbars",
        name = "Action bars",
        roots = {
            "MainActionBar",
            "MainMenuBar",
            "MultiBarBottomLeft",
            "MultiBarBottomRight",
            "MultiBarRight",
            "MultiBarLeft",
            "MultiBar5",
            "MultiBar6",
            "MultiBar7",
            "PetActionBar",
            "StanceBar",
            "MicroMenu",
            "BagsBar",
            "MainMenuBarEndCaps",
            "OverrideActionBar",
            "PossessActionBar",
            "ExtraAbilityContainer",
        },
    },
    { key = "minimap", name = "Minimap", roots = { "MinimapCluster" } },
    { key = "auras", name = "Buffs and debuffs", roots = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" } },
    { key = "bags", name = "Bags and bank", roots = { "ContainerFrameCombinedBags", "BankFrame", "ReagentBankFrame" } },
}

function app.addon:OnInitialize()
    local defaults = { enabled = true, color = { r = 0.22, g = 0.22, b = 0.22 }, categories = {} }
    for _, category in ipairs(app.categories) do
        defaults.categories[category.key] = true
    end
    app.db = LibStub("AceDB-3.0"):New("SeamlessDarkmodeDB", { profile = defaults }, true)
    app.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
    app.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    app.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    self:RegisterChatCommand("seamlessdarkmode", function()
        app.core:OpenOptions(appName)
    end)
end

function app.addon:OnEnable()
    app.running = true
    self:RegisterEvent("ADDON_LOADED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    -- Pooled aura, bag and unit buttons may appear without an addon-load event.
    self.timer = self:ScheduleRepeatingTimer("Refresh", 1)
    self:Refresh()
end

function app.addon:OnDisable()
    app.running = false
    self:CancelAllTimers()
    self:UnregisterAllEvents()
    app:Restore()
end
