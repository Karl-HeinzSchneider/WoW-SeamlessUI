---@type string, SeamlessDarkmode
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- A texture's color before it was first tinted, restored when its group is switched off.
---@type table<Texture, number[]>
local originals = setmetatable({}, { __mode = "k" })

---@param texture Texture?
local function tint(texture)
    if not texture then
        return
    end
    local original = originals[texture]
    if not original then
        original = { texture:GetVertexColor() }
        originals[texture] = original
    end
    local color = app.db.profile.color
    texture:SetVertexColor(color.r, color.g, color.b, original[4])
end

---@param texture Texture?
local function restore(texture)
    local original = texture and originals[texture]
    if original then
        texture:SetVertexColor(original[1], original[2], original[3], original[4])
        originals[texture] = nil
    end
end

function app.addon:OnInitialize()
    app.dbDefaults = app.core:GetOptionsDefaults(app.optionPages, app.dbDefaults)
    app.db = app.core:RegisterAddonDatabase(appName, app.dbDefaults, self, "Refresh", "SeamlessDarkmodeDB")
    self:RegisterChatCommand("seamlessdarkmode", function()
        app.core:OpenOptions(appName)
    end)
end

function app.addon:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InstallHooks")
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        icons.RegisterCallback(self, "LibDBIcon_IconCreated", "Refresh")
    end
    self:InstallHooks()
end

-- Containers can change from XP to reputation (or another bar) after login and during fades.
function app.addon:InstallHooks()
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container and not self:IsHooked(container, "ApplyPendingBarToShow") then
            self:SecureHook(container, "ApplyPendingBarToShow", "Refresh")
        end
    end
    self:Refresh()
end

function app.addon:OnDisable()
    self:UnregisterAllEvents()
    self:UnhookAll()
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        icons.UnregisterCallback(self, "LibDBIcon_IconCreated")
    end
    for _, group in ipairs(app.groups) do
        for _, frame in ipairs(group.frames) do
            frame(restore)
        end
    end
    app.StatusTrackingBars(restore, restore, restore)
end

-- Runs every frame function of every group, tinting or restoring by the current profile.
function app.addon:Refresh()
    if not self:IsEnabled() then
        return
    end
    local profile = app.db.profile
    app.StatusTrackingBars(
        (profile.enabled and profile.groups.experience) and tint or restore,
        (profile.enabled and profile.groups.reputation) and tint or restore,
        restore
    )
    for _, group in ipairs(app.groups) do
        local paint = (profile.enabled and profile.groups[group.key]) and tint or restore
        for _, frame in ipairs(group.frames) do
            frame(paint)
        end
    end
end
