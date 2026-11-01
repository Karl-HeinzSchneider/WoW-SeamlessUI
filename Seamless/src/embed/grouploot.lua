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

-- Keep the library's existing offsets in UIParent units; anchor choices are host-owned.
local function ApplyPosition(anchor)
    local profile = GetDatabase().profile
    local position, scale = profile.position, profile.scale
    anchor:SetScale(scale)
    anchor:ClearAllPoints()
    anchor:SetPoint(
        position.point or "BOTTOM",
        UIParent,
        position.relativePoint or "BOTTOM",
        position.x / scale,
        position.y / scale
    )
    if controller and controller.editMode then
        local default = controller.editMode.defaultPosition
        default.x, default.y = BGL.defaults.position.x / scale, BGL.defaults.position.y / scale
    end
end

local function SavePosition(anchor)
    local position, scale = GetDatabase().profile.position, anchor:GetScale()
    -- A drag always breaks the old anchor and stores the exact drop on UIParent.
    position.point, position.relativePoint = "BOTTOM", "BOTTOM"
    position.x = anchor:GetCenter() * scale - UIParent:GetWidth() / 2
    position.y = anchor:GetBottom() * scale
end

local function ResetPosition()
    local position = GetDatabase().profile.position
    position.point, position.relativePoint = nil, nil
    position.x, position.y = BGL.defaults.position.x, BGL.defaults.position.y
end

-- The anchor also parents real rolls, so it stays shown: only previews and the selection hide.
local function RefreshEditMode()
    if not (controller and controller.editMode) then
        return
    end
    local lib = controller.editMode.library
    local editing = lib:IsInEditMode()
    if editing and wanted and showInEditMode and controller.active and not InCombatLockdown() then
        controller:ShowPreviews()
    else
        controller:HidePreviews()
    end
    local selection = lib.frameSelections[controller.anchor]
    if selection and editing then
        if not (wanted and controller.active and showInEditMode) then
            selection:Hide()
        elseif not selection:IsShown() then
            selection:ShowHighlighted()
        end
    end
end

local function EditModeSettings(current, lib)
    local rows = current:GetEditModeSettings(lib, {
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
    -- Preserve the embedded rows' defaults, bounds, setters and combat guards.
    local scale, spacing, growUp, showUndecided = rows[1], rows[2], rows[3], rows[4]
    scale.formatter = function(value)
        return ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
    end
    local settings = {
        app.addon:GetEditModePositionSetting({
            get = function(key)
                local profile = GetDatabase().profile
                if key == "relativeTo" then
                    return "UIParent"
                elseif key == "point" or key == "relativePoint" then
                    return profile.position[key] or "BOTTOM"
                end
                return profile.position[key] / profile.scale
            end,
            set = function(key, value)
                if not current.active or InCombatLockdown() then
                    return
                end
                local profile = GetDatabase().profile
                if key == "x" or key == "y" then
                    profile.position[key] = value * profile.scale
                elseif key == "point" or key == "relativePoint" then
                    profile.position[key] = value
                end
                current:ApplySettings()
            end,
            anchorFrames = { { text = L["Screen (UIParent)"], value = "UIParent" } },
            disabled = function()
                return not current.active or InCombatLockdown()
            end,
        }, nil, { scale, spacing }),
        { name = L["Style"], kind = lib.SettingType.Header },
        growUp,
        showUndecided,
    }
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
    -- LibEditMode highlights every registered selection when another frame is selected.
    -- Keep the anchor shown for real rolls, but enforce our selection visibility on every show.
    lib.frameSelections[controller.anchor]:HookScript("OnShow", function(selection)
        if not (wanted and controller.active and showInEditMode) then
            selection:Hide()
        end
    end)
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
            defaultPosition = BGL.defaults.position,
            applyPosition = ApplyPosition,
            savePosition = SavePosition,
            resetPosition = ResetPosition,
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
        RefreshEditMode()
        app.addon:RefreshEditModeOptions()
    end,
    refresh = function()
        if controller then
            controller:OnProfileRefresh()
            RefreshEditMode()
        end
    end,
})
