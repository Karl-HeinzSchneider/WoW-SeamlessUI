-- Exercise the actual embedded XML/runtime, with only the WoW and UI shell mocked.
unpack = unpack or table.unpack
local combat, frames, hooks, removed, rolls, messages = false, 0, {}, 0, {}, {}
local names, nativeSyncs = {}, {}
local function noop() end
local function region(parent, name)
    local object = { parent = parent, name = name, events = {}, scripts = {}, points = {}, scale = 1 }
    return setmetatable(object, {
        __index = function(_, key)
            if key == "GetParent" then
                return function(self)
                    return self.parent
                end
            end
            if key == "GetName" then
                return function(self)
                    return self.name
                end
            end
            if key == "IsObjectType" then
                return function()
                    return true
                end
            end
            if key == "SetFrameStrata" then
                return function(self, value)
                    self.strata = value
                end
            end
            if key == "GetFrameStrata" then
                return function(self)
                    return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
                end
            end
            if key == "SetFrameLevel" then
                return function(self, value)
                    self.level = value
                end
            end
            if key == "GetFrameLevel" then
                return function(self)
                    return self.level or (self.parent and self.parent:GetFrameLevel() + 1) or 1
                end
            end
            if key == "SetScale" then
                return function(self, value)
                    self.scale = value
                end
            end
            if key == "GetScale" or key == "GetEffectiveScale" then
                return function(self)
                    return self.scale
                end
            end
            if key == "GetWidth" then
                return function()
                    return 1000
                end
            end
            if key == "GetHeight" then
                return function()
                    return 800
                end
            end
            if key == "ClearAllPoints" then
                return function(self)
                    self.points = {}
                end
            end
            if key == "SetPoint" then
                return function(self, ...)
                    self.points[1] = { ... }
                end
            end
            if key == "GetPoint" then
                return function(self)
                    return unpack(self.points[1] or {})
                end
            end
            if key == "GetNumPoints" then
                return function(self)
                    return #self.points
                end
            end
            if key == "Hide" then
                return function(self)
                    self.shown = false
                end
            end
            if key == "Show" then
                return function(self)
                    self.shown = true
                end
            end
            if key == "SetShown" then
                return function(self, value)
                    self.shown = not not value
                end
            end
            if key == "IsShown" then
                return function(self)
                    return self.shown
                end
            end
            if key == "CreateTexture" or key == "CreateFontString" or key:match("^Get.*Texture$") then
                return function(self)
                    return region(self)
                end
            end
            if key == "SetScript" then
                return function(self, event, callback)
                    self.scripts[event] = callback
                end
            end
            if key:match("^Set") or key:match("^Register") then
                return noop
            end
        end,
    })
end
function CreateFrame(_, name, parent)
    frames = frames + 1
    local frame = region(parent, name)
    if name then
        assert(not _G[name], name)
        _G[name] = frame
        names[#names + 1] = name
    end
    return frame
end
function Mixin(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end
function CreateObjectPool(create, reset)
    local free = {}
    return {
        Acquire = function()
            return table.remove(free) or create()
        end,
        Release = function(_, frame)
            reset(nil, frame)
            free[#free + 1] = frame
        end,
    }
end
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end
function InCombatLockdown()
    return combat
end
function GetBuildInfo()
    return "", "", "", 16001
end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
Enum = { ItemQuality = { Epic = 4 } }
ITEM_QUALITY_COLORS = {}
C_Item = {
    DoesItemExistByID = function()
        return false
    end,
}
C_Loot = {
    GetLootRollDuration = function()
        return 10000
    end,
}
C_LootHistory = {
    GetAllEncounterInfos = function()
        return {}
    end,
    GetSortedDropsForEncounter = function()
        return {}
    end,
}
function GetActiveLootRollIDs()
    return { 42 }
end
function GetLootRollItemInfo()
    return "icon", "Item", 1, 4, true, true, true, false
end
function GetLootRollItemLink()
    return "item:123"
end
function GetLootRollTimeLeft()
    return 10000
end
function RollOnLoot(id, choice)
    rolls[#rolls + 1] = { id, choice }
end
function hooksecurefunc(name, callback)
    hooks[name] = callback
end
GroupLootContainer_OpenNewFrame = noop
function GroupLootContainer_RemoveFrame(_, frame)
    removed = removed + 1
    frame.shown = false
end
GroupLootContainer = {}
function GroupLootContainer_RemoveAllRolls()
    GroupLootFrame1.shown = false
end
function GroupLootContainer_RefreshRolls()
    nativeSyncs[#nativeSyncs + 1] = BetterGroupLootRuntimeOwner.controller.active
    GroupLootFrame1.shown = true
    if hooks.GroupLootContainer_OpenNewFrame then
        hooks.GroupLootContainer_OpenNewFrame(42)
    end
end
C_Timer = {
    After = function(delay, callback)
        assert(delay == 0)
        callback()
    end,
}
GameTooltip = {
    IsOwned = function()
        return false
    end,
}
local translations = {}
local L = setmetatable({}, {
    __index = function(_, key)
        assert(translations[key], "Unlocalized: " .. key)
        return key
    end,
})
local libraries = {
    ["AceLocale-3.0"] = {
        NewLocale = function()
            return setmetatable({}, {
                __newindex = function(_, key)
                    translations[key] = true
                end,
            })
        end,
        GetLocale = function()
            return L
        end,
    },
    ["AceEvent-3.0"] = {
        Embed = function(_, target)
            target.events = {}
            target.RegisterEvent = function(self, event, handler)
                self.events[event] = handler
            end
            target.UnregisterEvent = function(self, event)
                self.events[event] = nil
            end
            target.UnregisterAllEvents = function(self)
                self.events = {}
            end
        end,
    },
    ["AceDBOptions-3.0"] = {
        GetOptionsTable = function()
            return { type = "group", name = "Profiles", args = {} }
        end,
    },
}
function LibStub(name)
    return assert(libraries[name], "Unexpected library: " .. name)
end
dofile("Seamless/locales/enUS.lua")
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local function loadXml(path, host)
    local directory = path:match("^(.*)/")
    for kind, name in read(path):gsub("<!%-%-.-%-%->", ""):gmatch("<(%w+)%s+file=[\"']([^\"']+)") do
        local child = directory .. "/" .. name:gsub("\\", "/")
        if kind == "Include" then
            loadXml(child, host)
        elseif kind == "Script" then
            assert(loadfile(child))("Seamless", host)
        end
    end
end
local support = dofile("src/tests/settings-support.lua")
local function host()
    for _, name in ipairs(names) do
        _G[name] = nil
    end
    names, hooks, messages, rolls = {}, {}, {}, {}
    BetterGroupLootRuntimeOwner, frames = nil, 0
    UIParent, TargetFrame = region(nil, "UIParent"), region(nil, "TargetFrame")
    nativeSyncs = {}
    GroupLootFrame1 = {
        rollID = 42,
        shown = true,
        IsShown = function(self)
            return self.shown
        end,
    }
    local lib = {
        SettingType = { Slider = 1, Checkbox = 2, Header = "header", Position = "position" },
        frameSelections = {},
        callbacks = {},
        registered = 0,
    }
    function lib:RegisterCallback(event, callback)
        self.callbacks[event] = self.callbacks[event] or {}
        table.insert(self.callbacks[event], callback)
    end
    function lib:IsInEditMode()
        return self.editing or false
    end
    function lib:AddFrame(frame, callback, default)
        self.registered = self.registered + 1
        self.frame, self.moved, self.default = frame, callback, default
        local selection = region(frame)
        selection.strata, selection.level = "MEDIUM", 1000
        self.frameSelections[frame] = selection
    end
    function lib:AddFrameSettings(_, settings)
        self.settings = settings
    end
    function lib:RefreshFrameSettings() end
    function lib:Enter()
        self.editing = true
        for _, fn in ipairs(self.callbacks.enter) do
            fn()
        end
    end
    function lib:Exit()
        self.editing = false
        for _, fn in ipairs(self.callbacks.exit) do
            fn()
        end
    end
    local core = {}
    local logger = { level = { INFO = 1 } }
    for _, level in ipairs({ "debug", "error", "chat" }) do
        logger[level] = function(_, message)
            assert(translations[message])
            messages[#messages + 1] = message
        end
    end
    local app =
        { addon = core, logger = logger, api = { untouched = true }, defaultLayout = { LAYOUT_NAME = "Seamless" } }
    function core:NewModule(_, module)
        return module
    end
    function core:GetEditModeLibrary()
        return lib
    end
    function core:RefreshOptions() end
    function core:RefreshEditModeOptions() end
    function core:RegisterEditModeOptions(id, spec)
        assert(id == "Seamless.GroupLoot")
        self.frameSpec = spec
    end
    function core:GetCustomEditModeVisibility(id, get, set)
        assert(id == "Seamless.GroupLoot")
        return function(value)
            if value ~= nil then
                set(value)
            end
            return get()
        end
    end
    function core:GetEditModePositionSetting(spec)
        return { kind = "position", position = spec }
    end
    core.GetEditModeButtonSection, core.GetEditModePositionButton = support.buttonSection, support.positionButton
    function core:GetFramePositionService()
        return {
            IsValidAnchorTarget = function(_, target, frame)
                return target ~= frame
            end,
            GetAnchorFrames = function()
                return { { value = "UIParent", text = "UIParent" }, { value = "TargetFrame", text = "TargetFrame" } }
            end,
        }
    end
    for _, file in ipairs({
        "core/db",
        "config/schema",
        "config/registry",
        "config/model",
        "config/position",
        "core/options",
    }) do
        assert(loadfile("Seamless/src/" .. file .. ".lua"))("Seamless", app)
    end
    loadXml("Seamless/src/embed/embed.xml", app)
    assert(app.api.untouched and app.logger == logger and app.RollController == nil)
    assert(frames == 0 and next(hooks) == nil and BetterGroupLootRuntimeOwner == nil)
    support.pages("Seamless", app)
    app.dbDefaults = core:GetOptionsDefaults(app.optionPages, app.dbDefaults)
    app.db = { profile = CopyTable(app.dbDefaults.profile), RegisterCallback = noop }
    app.options:OnInitialize()
    assert(app.config.categories["Seamless:groupLoot"].parent == "Seamless")
    assert(not app.db.profile.embed.BetterGroupLoot and app.optionPages.groupLoot.config.hidden())
    app.embed:OnEnable()
    assert(frames == 0)
    return app, lib, app.optionPages.embed.config.args.BetterGroupLoot
end

-- Standalone first: enabling/disabling the embed leaves the other owner untouched.
local app, lib, toggle = host()
local standalone = { prefix = "BetterGroupLoot", reason = "owned" }
BetterGroupLootRuntimeOwner = standalone
toggle.set(nil, true)
assert(not app.groupLoot.active and frames == 0 and lib.registered == 0)
assert(BetterGroupLootRuntimeOwner == standalone and next(hooks) == nil and #nativeSyncs == 0)
toggle.set(nil, false)
assert(BetterGroupLootRuntimeOwner == standalone)

-- Embedded first: actual roll startup, settings and isolated ownership.
app, lib, toggle = host()
toggle.set(nil, true)
local integration, controller = app.groupLoot, app.groupLoot.controller
assert(integration.active and lib.registered == 1 and #controller.frames == 1)
assert(nativeSyncs[1] == true and not GroupLootFrame1.shown)
assert(BetterGroupLootRuntimeOwner.prefix == "SeamlessGroupLoot")
assert(lib.frameSelections[controller.anchor]:GetFrameStrata() == "DIALOG")
assert(lib.settings[1].kind == "position" and lib.settings[2].kind == "header")
assert(lib.settings[#lib.settings] == app.optionPages.groupLoot.config.buttonSection)
assert(app.optionPages.groupLoot.config.args.style.args.scale == nil)
assert(not app.optionPages.groupLoot.config.hidden())
local other = { groupLoot = { logger = app.logger } }
loadXml("Seamless/src/embed/BetterGroupLoot/vendor/embedded.xml", other)
local count = frames
assert(other.groupLoot.StartGroupLoot({ prefix = "BetterGroupLoot" }) == nil)
assert(frames == count and other.groupLoot.api ~= integration.api)
lib:Enter()
assert(#controller.frames == 4 and lib.frameSelections[controller.anchor].shown)
local preview = app.addon.frameSpec.options[1]
preview.set(false)
assert(#controller.frames == 1 and not app.optionPages.groupLoot.config.editModeVisibility())
app.optionPages.groupLoot.config.editModeVisibility(true)
assert(preview.get() and #controller.frames == 4)
controller.frames[1].NeedButton:OnClick()
assert(rolls[1][1] == 42 and rolls[1][2] == 1)
local config = app.optionPages.groupLoot.config
config.args.style.args.spacing.set(nil, 17)
assert(app.db.profile.groupLoot.spacing == 17 and lib.settings[3].get() == 17)
config.args.position.args.relativeTo.set(nil, "SeamlessGroupLootAnchor")
assert(app.db.profile.groupLoot.position.relativeTo == "UIParent")
config.args.position.args.relativeTo.set(nil, "TargetFrame")
assert(controller.anchor.points[1][2] == TargetFrame)
lib.moved(controller.anchor, "Modern", "TOPRIGHT", -10, -20)
assert(app.db.profile.groupLoot.position.relativeTo == "UIParent")
assert(controller.anchor.points[1][2] == UIParent and controller.anchor.points[1][4] == -10)
local old = app.db.profile
app.db.profile = CopyTable(app.dbDefaults.profile)
app.db.profile.embed.BetterGroupLoot = true
app.embed:OnProfileRefresh()
assert(config.args.style.args.spacing.get() == 8 and old.groupLoot.spacing == 17)
assert(controller.anchor.points[1][4] == 600)
GroupLootFrame1.shown = true
hooks.GroupLootContainer_OpenNewFrame(42)
local closed = removed
combat = true
integration:UpdatePreview()
assert(#controller.frames == 1 and not lib.frameSelections[controller.anchor].shown)
combat = false
integration:UpdatePreview()
assert(#controller.frames == 4)
lib:Exit()
assert(#controller.frames == 1)
toggle.set(nil, false)
assert(not integration.active and #controller.frames == 0 and not controller.anchor.shown)
assert(nativeSyncs[#nativeSyncs] == false and GroupLootFrame1.shown)
hooks.GroupLootContainer_OpenNewFrame(42)
assert(removed == closed)
toggle.set(nil, true)
assert(integration.controller == controller and lib.registered == 1)

-- Combat startup is deferred; turning it back off cancels the pending startup.
app, lib, toggle = host()
combat = true
toggle.set(nil, true)
assert(frames == 0 and app.groupLoot.events.PLAYER_REGEN_ENABLED == "Enable")
toggle.set(nil, false)
assert(app.groupLoot.events.PLAYER_REGEN_ENABLED == nil and BetterGroupLootRuntimeOwner == nil)
toggle.set(nil, true)
combat = false
app.groupLoot:Enable()
assert(app.groupLoot.active and lib.registered == 1)
print("Group loot isolation, ownership, profile, settings, Edit Mode, movement and combat integration passed")
