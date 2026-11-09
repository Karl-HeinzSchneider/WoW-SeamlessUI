---@type string, SeamlessDarkmode
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- A texture's color before it was first tinted, restored when its part is switched off.
---@type table<Texture, number[]>
local originals = setmetatable({}, { __mode = "k" })

local restingStatusTinted = false

-- Mainline/PlayerFrame.lua (also loaded by Camelot) draws a gold overlay while
-- resting. Tint that overlay only; native combat/status updates keep their colors.
local function PaintPlayerStatus(enabled)
    local frame = _G.PlayerFrame
    if not frame then
        return
    end
    if frame.inCombat or frame.onHateList or not IsResting() then
        restingStatusTinted = false
        return
    end
    local status = frame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
    if not status then
        return
    end
    local profile = app.db.profile
    local playerEnabled = profile.groups.player
    if playerEnabled == nil then
        playerEnabled = profile.groups.unitframes
    end
    if enabled and playerEnabled then
        local override = profile.colors.unitframes
        local color = (override.enabled and override.color) or profile.color
        status:SetVertexColor(color.r, color.g, color.b, 1)
        restingStatusTinted = true
    elseif restingStatusTinted then
        -- Native IsResting branch in Blizzard_UnitFrame/Mainline/PlayerFrame.lua.
        status:SetVertexColor(1, 0.88, 0.25, 1)
        restingStatusTinted = false
    end
end

---@param texture Texture?
---@param color SeamlessDarkmode.Color
local function tint(texture, color)
    if not texture then
        return
    end
    local original = originals[texture]
    if not original then
        original = { texture:GetVertexColor() }
        originals[texture] = original
    end
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

-- An unset part of a split group still follows the old group setting in existing profiles.
function app.IsPartEnabled(category, part)
    local groups = app.db.profile.groups
    local enabled = groups[part.key]
    if enabled == nil and category.legacyGroup then
        return groups[category.legacyGroup]
    end
    return enabled
end

local function ApplyTint(enabled)
    local profile = app.db.profile
    local statusPainters = {}
    for _, category in ipairs(app.categories) do
        local paintTint = restore
        if enabled then
            local override = profile.colors[category.key]
            local color = (override.enabled and override.color) or profile.color
            paintTint = function(texture)
                tint(texture, color)
            end
        end
        for _, part in ipairs(category.parts) do
            local paint = enabled and app.IsPartEnabled(category, part) and paintTint or restore
            if part.frame then
                part.frame(paint)
            else
                statusPainters[part.key] = paint
            end
        end
    end
    app.StatusTrackingBars(statusPainters.experience, statusPainters.reputation, restore)
    PaintPlayerStatus(enabled)
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
    if _G.PlayerFrame_UpdateStatus and not self:IsHooked("PlayerFrame_UpdateStatus") then
        self:SecureHook("PlayerFrame_UpdateStatus", "RefreshPlayerStatus")
    end
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container and not self:IsHooked(container, "ApplyPendingBarToShow") then
            self:SecureHook(container, "ApplyPendingBarToShow", "Refresh")
        end
    end
    self:Refresh()
end

function app.addon:RefreshPlayerStatus()
    PaintPlayerStatus(self:IsEnabled() and app.db.profile.enabled)
end

function app.addon:OnDisable()
    self:UnregisterAllEvents()
    self:UnhookAll()
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        icons.UnregisterCallback(self, "LibDBIcon_IconCreated")
    end
    ApplyTint(false)
end

function app.addon:Refresh()
    if self:IsEnabled() then
        ApplyTint(app.db.profile.enabled)
    end
end
