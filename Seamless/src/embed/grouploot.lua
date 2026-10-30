---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Adapter for the vendored BetterGroupLoot-1.0 roll frames (Seamless/lib/BetterGroupLoot-1.0).
-- The library is loaded by embed.xml and does nothing until Start.
local BGL = LibStub("BetterGroupLoot-1.0")

-- Frames are SeamlessGroupLootAnchor and SeamlessGroupLootRollFrame<N>.
local PREFIX = "SeamlessGroupLoot"
-- AceDB namespace under SeamlessDB, so the settings follow the suite profile.
local NAMESPACE = "GroupLoot"

-- The library's controller (its annotations live in lib/, which LuaLS skips).
---@type table?
local controller
local database
local wanted = false
-- Edit Mode previews and selection, session-only like the other Frames checkboxes.
local showInEditMode = true
local events = CreateFrame("Frame")

local function GetDatabase()
    if not database then
        database = app.db:GetNamespace(NAMESPACE, true)
            or app.db:RegisterNamespace(NAMESPACE, { profile = CopyTable(BGL.defaults) })
    end
    return database
end

local function IsRegistered()
    return wanted and controller ~= nil and controller.editMode ~= nil
end

-- The anchor also parents real rolls, so it stays shown: only previews and the selection hide.
local function RefreshEditMode()
    if not IsRegistered() then
        return
    end
    local lib = controller.editMode.library
    local editing = lib:IsInEditMode()
    if editing and showInEditMode and controller.active and not InCombatLockdown() then
        controller:ShowPreviews()
    else
        controller:HidePreviews()
    end
    local selection = lib.frameSelections[controller.anchor]
    if selection and editing then
        if not showInEditMode then
            selection:Hide()
        elseif not selection:IsShown() then
            selection:ShowHighlighted()
        end
    end
end

local function EditModeSettings(current, lib)
    local settings = current:GetEditModeSettings(lib, {
        defaults = BGL.defaults,
        strings = {
            scale = L["Scale"],
            spacing = L["Spacing"],
            spacingDescription = L["Gap between two rolls."],
            growUp = L["Stack upwards"],
            growUpDescription = L["New rolls appear above the first one. Off: below it."],
            showUndecided = L["List undecided players"],
            showUndecidedDescription = L["The roll buttons' tooltips also list who hasn't chosen yet."],
        },
    })
    settings[#settings + 1] = app.addon:GetEditModeButtonSection({
        app.addon:GetEditModePositionButton("revert"),
        app.addon:GetEditModePositionButton("resetPosition"),
    })
    return settings
end

-- LibEditMode registration must happen outside combat; it is kept for the session and
-- stays dormant while the controller is stopped.
local function RegisterEditMode()
    if not (wanted and controller) or controller.editMode then
        return
    end
    if InCombatLockdown() then
        return
    end
    local lib = app.addon:GetEditModeLibrary()
    controller:RegisterEditMode(lib, {
        name = L["Group loot"],
        settings = EditModeSettings,
        managePreviews = false,
    })
    for _, event in ipairs({ "enter", "exit", "layout" }) do
        lib:RegisterCallback(event, RefreshEditMode)
    end
    app.addon:RefreshEditModeOptions()
end

events:SetScript("OnEvent", function()
    RegisterEditMode()
    RefreshEditMode()
end)

app.addon:RegisterEditModeOptions("Seamless.GroupLoot", {
    section = "frames",
    enabled = IsRegistered,
    options = {
        {
            key = "groupLoot",
            type = "toggle",
            name = L["Group loot"],
            get = function()
                return showInEditMode
            end,
            set = function(value)
                showInEditMode = value
                EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                RefreshEditMode()
            end,
        },
    },
})

app.embed:Register("groupLoot", {
    name = L["Group loot"],
    default = true,
    enable = function()
        wanted = true
        local owner
        controller, owner = BGL:Start({
            name = PREFIX,
            logger = app.logger,
            getProfile = function()
                return GetDatabase().profile
            end,
            strings = {
                undecided = L["Undecided"],
                offSpec = L["off spec"],
                noData = L["No roll data yet."],
                nobody = L["Nobody yet."],
            },
        })
        if not controller then
            if owner and owner.reason == "unsupported" then
                app.logger:warn(L["Group loot rolls are not supported on this client."])
            else
                -- Expected with the standalone addon installed, which starts first.
                app.logger:debug(L["Group loot rolls are already shown by %s."], owner and owner.prefix or "?")
            end
            return
        end
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        RegisterEditMode()
        RefreshEditMode()
        app.addon:RefreshEditModeOptions()
    end,
    disable = function()
        wanted = false
        events:UnregisterAllEvents()
        -- Only stop the runtime this adapter started; another owner's controller is never touched.
        if controller then
            controller:Stop()
        end
        app.addon:RefreshEditModeOptions()
    end,
    refresh = function()
        if controller then
            controller:OnProfileRefresh()
            RefreshEditMode()
        end
    end,
})
