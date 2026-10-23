---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local log = app.logger

-- The suite's Edit Mode layout, shipped as an account layout named LAYOUT_NAME and built from
-- app.defaultLayoutString. It cannot be a real preset next to Modern and Classic: presets live in
-- EditModePresetLayoutManager, the client counts their indices in C, and an addon entry there would
-- taint Blizzard's secure layout code. This module never writes EditModeManagerFrame's tables; it
-- saves through C_EditMode and lets Blizzard reload the layouts from the event that follows.
local LAYOUT_NAME = "SeamlessUI (Preset)"

---@class SeamlessCore.DefaultLayout : AceModule, AceEvent-3.0
---@field LAYOUT_NAME string The layout's name in Edit Mode.
local module = {}
app.defaultLayout = app.addon:NewModule("DefaultLayout", module, "AceEvent-3.0") --[[@as SeamlessCore.DefaultLayout]]
module.LAYOUT_NAME = LAYOUT_NAME

-- The saved layouts with a copy of Blizzard's presets in front, indexed like SetActiveLayout.
local function LoadLayouts()
    local info = C_EditMode.GetLayouts()
    local layouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    tAppendAll(layouts, info.layouts)
    info.layouts = layouts
    return info
end

---@return number? index
local function FindLayout(info)
    for index, layout in ipairs(info.layouts) do
        if layout.layoutType ~= Enum.EditModeLayoutType.Preset and layout.layoutName == LAYOUT_NAME then
            return index
        end
    end
end

-- Where the native import puts an account layout: after the last account layout, so before
-- every character layout. Also returns how many account layouts exist.
local function NewAccountLayoutIndex(info)
    local last, count = 0, 0
    for index, layout in ipairs(info.layouts) do
        local layoutType = layout.layoutType
        if layoutType == Enum.EditModeLayoutType.Preset or layoutType == Enum.EditModeLayoutType.Account then
            last = index
        end
        if layoutType == Enum.EditModeLayoutType.Account then
            count = count + 1
        end
    end
    return last + 1, count
end

-- Adds the layout with the same calls the native import makes. Blizzard reloads its layout list
-- only when the active layout changes, so the new layout is activated even when `activate` is
-- false; the previous layout is then selected again, shifted past the inserted index.
---@return boolean ok, string? err
local function Create(info, activate)
    local index, count = NewAccountLayoutIndex(info)
    if count >= Constants.EditModeConsts.EditModeMaxLayoutsPerType then
        return false, L["All account layout slots are in use. Delete one in Edit Mode to add the Seamless layout."]
    end
    local ok, layout = pcall(C_EditMode.ConvertStringToLayoutInfo, app.defaultLayoutString)
    if not ok or type(layout) ~= "table" or not C_EditMode.IsValidLayoutName(LAYOUT_NAME) then
        return false, L["The Seamless layout could not be read."]
    end
    local previous = info.activeLayout
    if previous >= index then
        previous = previous + 1
    end
    layout.layoutType = Enum.EditModeLayoutType.Account
    layout.layoutName = LAYOUT_NAME
    table.insert(info.layouts, index, layout)
    C_EditMode.SaveLayouts(info)
    C_EditMode.OnLayoutAdded(index, true, true)
    if not activate then
        C_EditMode.SetActiveLayout(previous)
    end
    return true
end

---@return boolean ok, string? err
local function CanChange()
    if InCombatLockdown() then
        return false, ERR_NOT_IN_COMBAT
    end
    if not EditModeManagerFrame or not EditModeManagerFrame:IsInitialized() then
        return false, L["Edit Mode is not ready yet."]
    end
    if EditModeManagerFrame:IsEditModeActive() then
        return false, L["Close Edit Mode first."]
    end
    return true
end

-- Switches to the Seamless layout, adding it again if it is missing.
---@return boolean ok, string? err
function module:Use()
    local ok, err = CanChange()
    if not ok then
        return false, err
    end
    local info = LoadLayouts()
    local index = FindLayout(info)
    if index then
        if index ~= info.activeLayout then
            C_EditMode.SetActiveLayout(index)
        end
        return true
    end
    return Create(info, true)
end

-- Once per session: adds the account layout when it is missing, without switching to it.
-- Players choose it in Edit Mode, or copy it to make their own.
function module:Check()
    local ok = CanChange()
    if not ok then
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", "Schedule")
        end
        -- Otherwise the next EDIT_MODE_LAYOUTS_UPDATED tries again.
        return
    end
    self:UnregisterAllEvents()
    local info = LoadLayouts()
    if FindLayout(info) then
        return
    end
    local created, err = Create(info, false)
    if created then
        log:info(L["Added the %s Edit Mode layout. Choose it in Edit Mode, or copy it to make your own."], LAYOUT_NAME)
    else
        -- Full slots are the player's choice; say so only when they ask through the options.
        log:debug(err)
    end
end

-- Next frame: Blizzard's own EDIT_MODE_LAYOUTS_UPDATED handler has to run first.
function module:Schedule()
    C_Timer.After(0, function()
        self:Check()
    end)
end

function module:OnEnable()
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "Schedule")
    if EditModeManagerFrame and EditModeManagerFrame:IsInitialized() then
        self:Schedule()
    end
end
