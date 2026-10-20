---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.BlizzardEditMode : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("BlizzardEditMode", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.BlizzardEditMode]]
app.blizzardEditMode = module
module:SetEnabledState(false)

local frames = {}
local function add(key, name, system, indices, index, category)
    frames[#frames + 1] =
        { key = key, name = name, system = system, indices = indices, index = index, category = category }
end
add("player", L["Player frame"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Player", "units")
add("target", L["Target frame"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Target", "units")
add("pet", L["Pet frame"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Pet", "units")
add("focus", L["Focus frame"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Focus", "units")
add("party", L["Party frames"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Party", "units")
add("raid", L["Raid frames"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Raid", "units")
add("boss", L["Boss frames"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Boss", "units")
add("arena", L["Arena frames"], "UnitFrame", "EditModeUnitFrameSystemIndices", "Arena", "units")
add(
    "actionBar1",
    string.format(L["Action bar %d"], 1),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "MainBar",
    "bars"
)
add("actionBar2", string.format(L["Action bar %d"], 2), "ActionBar", "EditModeActionBarSystemIndices", "Bar2", "bars")
add("actionBar3", string.format(L["Action bar %d"], 3), "ActionBar", "EditModeActionBarSystemIndices", "Bar3", "bars")
add(
    "actionBar4",
    string.format(L["Action bar %d"], 4),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "RightBar1",
    "bars"
)
add(
    "actionBar5",
    string.format(L["Action bar %d"], 5),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "RightBar2",
    "bars"
)
add(
    "actionBar6",
    string.format(L["Action bar %d"], 6),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "ExtraBar1",
    "bars"
)
add(
    "actionBar7",
    string.format(L["Action bar %d"], 7),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "ExtraBar2",
    "bars"
)
add(
    "actionBar8",
    string.format(L["Action bar %d"], 8),
    "ActionBar",
    "EditModeActionBarSystemIndices",
    "ExtraBar3",
    "bars"
)
add("stanceBar", L["Stance bar"], "ActionBar", "EditModeActionBarSystemIndices", "StanceBar", "bars")
add("petBar", L["Pet action bar"], "ActionBar", "EditModeActionBarSystemIndices", "PetActionBar", "bars")
add("possessBar", L["Possess action bar"], "ActionBar", "EditModeActionBarSystemIndices", "PossessActionBar", "bars")
add("buffs", L["Buffs"], "AuraFrame", "EditModeAuraFrameSystemIndices", "BuffFrame", "auras")
add("debuffs", L["Debuffs"], "AuraFrame", "EditModeAuraFrameSystemIndices", "DebuffFrame", "auras")
add(
    "statusBar1",
    string.format(L["XP / reputation bar %d"], 1),
    "StatusTrackingBar",
    "EditModeStatusTrackingBarSystemIndices",
    "StatusTrackingBar1",
    "other"
)
add(
    "statusBar2",
    string.format(L["XP / reputation bar %d"], 2),
    "StatusTrackingBar",
    "EditModeStatusTrackingBarSystemIndices",
    "StatusTrackingBar2",
    "other"
)
add("minimap", L["Minimap"], "Minimap", nil, nil, "other")
add("castBar", L["Cast bar"], "CastBar", nil, nil, "other")
add("encounterBar", L["Encounter bar"], "EncounterBar", nil, nil, "other")
add("extraAbilities", L["Extra abilities"], "ExtraAbilities", nil, nil, "other")
add("objectiveTracker", L["Objective tracker"], "ObjectiveTracker", nil, nil, "other")
add("microMenu", L["Micro menu"], "MicroMenu", nil, nil, "other")
add("bags", L["Bags"], "Bags", nil, nil, "other")
add("vehicleLeave", L["Leave vehicle button"], "VehicleLeaveButton", nil, nil, "other")
add("vehicleSeat", L["Vehicle seat indicator"], "VehicleSeatIndicator", nil, nil, "other")
add("loot", L["Loot frame"], "LootFrame", nil, nil, "other")
add("tooltip", L["Tooltip"], "HudTooltip", nil, nil, "other")
add("durability", L["Durability indicator"], "DurabilityFrame", nil, nil, "other")
add("timers", L["Timer bars"], "TimerBars", nil, nil, "other")
add("chat", L["Chat frame"], "ChatFrame", nil, nil, "other")
add("talkingHead", L["Talking head"], "TalkingHeadFrame", nil, nil, "other")
add("resource", L["Personal resource display"], "PersonalResourceDisplay", nil, nil, "other")
add("totems", L["Totem action bar"], "TotemActionBar", nil, nil, "other")
add("raidWarning", L["Raid warning"], "RaidWarning", nil, nil, "other")
add("groupFinder", L["Group finder"], "GroupFinder", nil, nil, "other")
add("lossOfControl", L["Loss of control"], "LossOfControl", nil, nil, "other")
add("archaeology", L["Archaeology bar"], "ArchaeologyBar", nil, nil, "other")
add("swingMainHand", L["Main-hand swing timer"], "SwingTimer", "EditModeSwingTimerSystemIndices", "MainHand", "other")
add("swingOffHand", L["Off-hand swing timer"], "SwingTimer", "EditModeSwingTimerSystemIndices", "OffHand", "other")
add("swingRanged", L["Ranged swing timer"], "SwingTimer", "EditModeSwingTimerSystemIndices", "Ranged", "other")

local categories = {
    { key = "units", name = L["Unit frames"] },
    { key = "bars", name = L["Action bars"] },
    { key = "auras", name = L["Auras"] },
    { key = "other", name = L["Other frames"] },
}

local function matches(system, spec)
    local id = Enum.EditModeSystem[spec.system]
    if not id or system.system ~= id then
        return false
    end
    if spec.index then
        local indices = Enum[spec.indices]
        local index = indices and indices[spec.index]
        return index ~= nil and system.systemIndex == index
    end
    return true
end

local function available(spec)
    local manager = EditModeManagerFrame
    for _, system in ipairs(manager and manager.registeredSystemFrames or {}) do
        if matches(system, spec) then
            return true
        end
    end
    return false
end

-- Use the actual registered object's name rather than guessing globals for
-- composite frames such as raid groups and status-tracking containers.
function module:GetAnchorTargets()
    local targets, seen, labels = {}, {}, {}
    local manager = EditModeManagerFrame
    for _, system in ipairs(manager and manager.registeredSystemFrames or {}) do
        for _, spec in ipairs(frames) do
            if matches(system, spec) and spec.key ~= "minimap" then
                local name = system.GetName and system:GetName()
                if name and _G[name] == system and not seen[name] then
                    seen[name] = true
                    targets[#targets + 1] = { value = name, text = spec.name }
                    labels[spec.name] = (labels[spec.name] or 0) + 1
                end
                break
            end
        end
    end
    for _, entry in ipairs(targets) do
        if labels[entry.text] > 1 then
            entry.text = string.format(L["%s (%s)"], entry.text, entry.value)
        end
    end
    return targets
end

local panel, title, positionView

local function settings()
    return app.db.profile.blizzardEditMode
end

local function hidePanel()
    if panel then
        panel:Hide()
    end
end

local function ensurePanel()
    if panel then
        return
    end
    -- LibEditMode has no public unregister/hide API for system extensions. Own this
    -- panel so the recovery switches can remove it without library internals.
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    panel:SetHeight(60)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetPoint("TOPLEFT", EditModeSystemSettingsDialog, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("TOPRIGHT", EditModeSystemSettingsDialog, "BOTTOMRIGHT", 0, -8)
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(panel:GetFrameLevel())
    title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetPoint("TOPRIGHT", -24, -20)
end

function module:GetSelectedFrame()
    local dialog = EditModeSystemSettingsDialog
    local manager = EditModeManagerFrame
    if
        not self:IsEnabled()
        or not settings().enabled
        or InCombatLockdown()
        or not dialog
        or not dialog:IsShown()
        or not manager
        or not manager:IsEditModeActive()
    then
        return
    end
    local system = dialog.attachedToSystem
    if not system then
        return
    end
    for _, spec in ipairs(frames) do
        if matches(system, spec) and settings().frames[spec.key].enabled then
            return system, spec
        end
    end
end

function module:RefreshPanel()
    local system, spec = self:GetSelectedFrame()
    if not system then
        hidePanel()
        return
    end
    ensurePanel()
    title:SetText(string.format(L["SeamlessUI - %s"], spec.name))
    panel:SetFrameLevel(EditModeSystemSettingsDialog:GetFrameLevel() + 10)
    if settings().frames[spec.key].addPosition then
        positionView = positionView or app.blizzardPosition:Create(panel)
        positionView:Refresh(system)
        positionView:Show()
    else
        if positionView then
            positionView:Hide()
        end
        panel:SetHeight(60)
    end
    panel:Show()
end

function module:InstallHooks()
    local dialog = EditModeSystemSettingsDialog
    if not dialog or not EditModeManagerFrame or self:IsHooked(dialog, "AttachToSystemFrame") then
        return
    end
    self:SecureHook(dialog, "AttachToSystemFrame", "RefreshPanel")
    self:SecureHookScript(dialog, "OnShow", "RefreshPanel")
    self:SecureHookScript(dialog, "OnHide", hidePanel)
    self:SecureHookScript(EditModeManagerFrame, "OnHide", hidePanel)
    self:RefreshPanel()
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", hidePanel)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshPanel")
    self:InstallHooks()
end

function module:OnDisable()
    hidePanel()
    self:UnhookAll()
    self:UnregisterAllEvents()
end

function module:OnProfileRefresh()
    if not IsLoggedIn() then
        self:SetEnabledState(settings().enabled)
    elseif settings().enabled then
        self:Enable()
        self:RefreshPanel()
    else
        self:Disable()
    end
end

function module:Options()
    local args = {
        enabled = {
            type = "toggle",
            order = 1,
            width = "full",
            name = L["Enable Blizzard Edit Mode extensions"],
            desc = L["Adds a SeamlessUI window below the selected Blizzard frame's Edit Mode settings. Turn off to disable all extensions."],
            descStyle = "inline",
            get = function()
                return settings().enabled
            end,
            set = function(_, value)
                settings().enabled = value
                module:OnProfileRefresh()
            end,
        },
    }
    for categoryOrder, category in ipairs(categories) do
        args[category.key .. "Heading"] = {
            type = "header",
            order = categoryOrder * 1000,
            name = category.name,
            hidden = function()
                for _, spec in ipairs(frames) do
                    if spec.category == category.key and available(spec) then
                        return false
                    end
                end
                return true
            end,
        }
    end
    for order, spec in ipairs(frames) do
        local key = spec.key
        local categoryOrder = 1
        for index, category in ipairs(categories) do
            if category.key == spec.category then
                categoryOrder = index
            end
        end
        args[key] = {
            type = "group",
            inline = true,
            order = categoryOrder * 1000 + order,
            hidden = function()
                return not available(spec)
            end,
            name = spec.name,
            disabled = function()
                return not settings().enabled
            end,
            get = function(info)
                return settings().frames[key][info[#info]]
            end,
            set = function(info, value)
                settings().frames[key][info[#info]] = value
                module:RefreshPanel()
            end,
            args = {
                enabled = {
                    type = "toggle",
                    order = 1,
                    width = "full",
                    name = L["Extend Edit Mode"],
                    desc = L["Show the SeamlessUI extension when this frame is selected in Edit Mode. Turn off if this frame causes issues."],
                },
                addPosition = {
                    type = "toggle",
                    order = 2,
                    name = L["Add position"],
                    desc = L["Adds Anchor, AnchorParent, AnchorFrame, X and Y controls to this frame's Edit Mode extension."],
                    disabled = function()
                        return not settings().enabled or not settings().frames[key].enabled
                    end,
                },
                addMoreOptions = {
                    type = "toggle",
                    order = 3,
                    name = L["Add more options"],
                    desc = L["Reserved for future frame options. This setting has no effect yet."],
                    disabled = function()
                        return not settings().enabled or not settings().frames[key].enabled
                    end,
                },
            },
        }
    end
    return { order = 30, name = L["Blizzard Edit Mode Extensions"], args = args }
end
