---@type string, SeamlessCore
local _, coreApp = ...
local app, core = coreApp.groupLoot, coreApp.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lib = core:GetEditModeLibrary()
local ID = "Seamless.GroupLoot"

-- Rebuild already-running rolls when toggling mid-roll. While our controller is
-- active its upstream hook suppresses the rebuilt native frames; after Stop the
-- same public refresh restores Blizzard's buttons with the current roll timers.
local function refreshNativeRolls()
    if
        app.api.IsRollUIActive()
        and GroupLootContainer
        and GroupLootContainer_RemoveAllRolls
        and GroupLootContainer_RefreshRolls
    then
        GroupLootContainer_RemoveAllRolls(GroupLootContainer)
        GroupLootContainer_RefreshRolls()
    end
end

local function refreshNavigation()
    -- The frame page appears/disappears with the embed checkbox. Rebuild the
    -- navigation after the current control callback, alongside deferred row refresh.
    C_Timer.After(0, function()
        core:RefreshConfig()
    end)
end

function app:GetProfile()
    return coreApp.db.profile.groupLoot
end

function app:RefreshOptions()
    core:RefreshOptions("Seamless")
end

function app:ApplySettings()
    if self.controller then
        self.controller:ApplySettings()
    end
end

function app:ApplyPosition(frame)
    local profile = self:GetProfile()
    local position = profile.position
    local target = _G[position.relativeTo]
    if
        not target
        or not target.IsObjectType
        or not target:IsObjectType("Frame")
        or not core:GetFramePositionService():IsValidAnchorTarget(target, frame)
    then
        target = UIParent
    end
    frame:SetScale(profile.scale)
    frame:ClearAllPoints()
    frame:SetPoint(position.point, target, position.relativePoint, position.x, position.y)
end

function app:SavePosition(frame, point, x, y)
    if not point then
        local position = { frame:GetPoint(1) }
        point, x, y = position[1], position[4], position[5]
    end
    -- Dragging breaks the old anchor. The library has already normalized the
    -- dropped frame onto UIParent; preserve that exact position.
    self:GetProfile().position = { point = point, relativePoint = point, relativeTo = "UIParent", x = x, y = y }
    self:ApplyPosition(frame)
    self:RefreshOptions()
end

function app:ResetPosition(frame)
    self:GetProfile().position = CopyTable(self.defaults.position)
    self:ApplyPosition(frame)
end

function app:UpdatePreview()
    local controller = self.controller
    if not controller then
        return
    end
    local shown = self.active and self.preview and lib:IsInEditMode() and not InCombatLockdown()
    if shown then
        controller:ShowPreviews()
    else
        controller:HidePreviews()
    end
    local selection = lib.frameSelections[controller.anchor]
    if selection then
        selection:SetShown(shown)
    end
    core:RefreshEditModeOptions()
end

function app:Refresh()
    if self.controller and self.active then
        self.controller:OnProfileRefresh()
    end
    self:UpdatePreview()
    self:RefreshOptions()
end

function app:Enable()
    self.requested = true
    refreshNavigation()
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "Enable")
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local controller, owner = self.StartGroupLoot({
        prefix = "SeamlessGroupLoot",
        getProfile = function()
            return self:GetProfile()
        end,
        applyPosition = function(frame)
            self:ApplyPosition(frame)
        end,
        savePosition = function(frame)
            self:SavePosition(frame)
        end,
        resetPosition = function(frame)
            self:ResetPosition(frame)
        end,
        changed = function()
            self:RefreshOptions()
        end,
        moverText = L["Group loot"],
    })
    if not controller then
        coreApp.logger:chat(L["Group loot could not start (%s)."], owner.prefix or owner.reason)
        self:RefreshOptions()
        return
    end
    self.controller, self.active = controller, true
    refreshNativeRolls()
    local default = self.defaults.position
    controller:RegisterEditMode(lib, {
        name = L["Group loot"],
        defaultPosition = { point = default.point, x = default.x, y = default.y },
        managePreviews = false,
        onMoved = function(frame, _, point, x, y)
            self:SavePosition(frame, point, x, y)
        end,
        settings = function()
            local settings = {
                core:GetEditModePositionSetting(self.positionSpec),
                { name = L["Style"], kind = lib.SettingType.Header },
            }
            for _, row in ipairs(self.styleSettings) do
                settings[#settings + 1] = row
            end
            settings[#settings + 1] = coreApp.optionPages.groupLoot.config.buttonSection
            return settings
        end,
    })
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdatePreview")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdatePreview")
    self:Refresh()
end

function app:Disable()
    local wasActive = self.active
    self.requested, self.active = false, false
    refreshNavigation()
    self:UnregisterAllEvents()
    if self.controller then
        self.controller:Stop()
    end
    if wasActive then
        refreshNativeRolls()
    end
    self:UpdatePreview()
    self:RefreshOptions()
end

app.positionSpec = {
    get = function(key)
        return app:GetProfile().position[key]
    end,
    set = function(key, value)
        if not app.active or InCombatLockdown() then
            return
        end
        if key == "relativeTo" then
            local target = _G[value]
            if not target or not core:GetFramePositionService():IsValidAnchorTarget(target, app.controller.anchor) then
                return
            end
        end
        app:GetProfile().position[key] = value
        app:ApplySettings()
        app:RefreshOptions()
    end,
    default = function(key)
        return app.defaults.position[key]
    end,
    anchorFrames = function()
        return app.controller and core:GetFramePositionService():GetAnchorFrames(app.controller.anchor)
            or { { text = L["UIParent"], value = "UIParent" } }
    end,
    disabled = function()
        return not app.active or InCombatLockdown()
    end,
    scale = {
        get = function()
            return app:GetProfile().scale
        end,
        set = function(value)
            if not app.active or InCombatLockdown() then
                return
            end
            app:GetProfile().scale = value
            app:ApplySettings()
            app:RefreshOptions()
        end,
        min = 0.5,
        max = 2,
        step = 0.05,
        default = 1,
    },
    reset = function()
        if app.active and not InCombatLockdown() then
            app.controller:ResetPosition()
            app:RefreshOptions()
        end
    end,
}
local function preview(value)
    if value ~= nil then
        app.preview = value
        app:UpdatePreview()
    end
    return app.preview
end
app.editModeVisibility = core:GetCustomEditModeVisibility(ID, preview, preview)
core:RegisterEditModeOptions(ID, {
    section = "frames",
    order = 600,
    enabled = function()
        return app.active
    end,
    options = { { key = "preview", type = "toggle", name = L["Group loot"], get = preview, set = preview } },
})
for _, event in ipairs({ "enter", "exit", "layout" }) do
    lib:RegisterCallback(event, function()
        app:UpdatePreview()
    end)
end
coreApp.embed:Register("BetterGroupLoot", {
    name = L["Group loot"],
    order = 100,
    enable = function()
        app:Enable()
    end,
    disable = function()
        app:Disable()
    end,
    refresh = function()
        app:Refresh()
    end,
})
