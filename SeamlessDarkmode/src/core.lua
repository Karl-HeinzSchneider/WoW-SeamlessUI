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

-- These events can create/reparent supported frames; aura buttons are preallocated
-- by AuraFrame_OnLoad, so UNIT_AURA and per-frame updates need no discovery work.
local discoveryEvents = {
    ADDON_LOADED = false,
    PLAYER_ENTERING_WORLD = false,
    GROUP_ROSTER_UPDATE = "unitframes",
    BAG_UPDATE_DELAYED = "bags",
    BANKFRAME_OPENED = "bags",
    UPDATE_SHAPESHIFT_FORMS = "actionbars",
}

function app.addon:QueueDiscovery(category)
    if not app.running then
        return
    end
    self.pendingCategories = self.pendingCategories or {}
    if category then
        self.pendingCategories[category] = true
    else
        for _, entry in ipairs(app.categories) do
            self.pendingCategories[entry.key] = true
        end
    end
    if not self.discoveryTimer and not InCombatLockdown() then
        self.discoveryTimer = self:ScheduleTimer("FlushDiscovery", 0.05)
    end
end

function app.addon:OnDiscoveryEvent(event)
    self:QueueDiscovery(discoveryEvents[event] or nil)
end

function app.addon:FlushDiscovery()
    self.discoveryTimer = nil
    if not app.running or InCombatLockdown() then
        return
    end
    local pending = self.pendingCategories or {}
    self.pendingCategories = nil
    for category in pairs(pending) do
        app:DiscoverCategory(category)
    end
end

function app.addon:OnCombatEnded()
    if self.refreshPending then
        self:Refresh()
    end
    self:FlushDiscovery()
end

function app.addon:OnEnable()
    app.running = true
    for event in pairs(discoveryEvents) do
        self:RegisterEvent(event, "OnDiscoveryEvent")
    end
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
    self:Refresh()
end

function app.addon:OnDisable()
    app.running = false
    self:CancelAllTimers()
    self.discoveryTimer = nil
    self.pendingCategories = nil
    self.refreshPending = nil
    self:UnregisterAllEvents()
    app:Restore()
end
