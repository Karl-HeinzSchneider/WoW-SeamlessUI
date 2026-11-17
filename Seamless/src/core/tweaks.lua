---@type string, SeamlessCore
local _, app = ...

local log = app.logger

---@class SeamlessCore.Tweaks : AceModule, AceConsole-3.0, AceEvent-3.0
---@field active? boolean
---@field lfgPlaystyleHooked? boolean
local module = {}
app.tweaks = app.addon:NewModule("Tweaks", module, "AceConsole-3.0", "AceEvent-3.0") --[[@as SeamlessCore.Tweaks]]

local LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"

function module:HookListingPlaystyle(_, addonName)
    if addonName and addonName ~= LFG_ADDON then
        return
    end
    if self.lfgPlaystyleHooked or not LFGListingActivityView_SetupPlayStyleDropdown then
        return
    end

    self.lfgPlaystyleHooked = true
    self:UnregisterEvent("ADDON_LOADED")
    hooksecurefunc("LFGListingActivityView_OnPlayStyleSelectedInternal", function(view, playstyle)
        local tweaks = app.db.profile.tweaks
        if
            self.active
            and tweaks.rememberListingPlaystyle
            and view.PlayStyleDropdown
            and not C_LFGList.HasActiveEntryInfo()
        then
            tweaks.lastListingPlaystyle = playstyle
        end
    end)
    hooksecurefunc("LFGListingActivityView_SetupPlayStyleDropdown", function(view)
        local tweaks = app.db.profile.tweaks
        local playstyle = tweaks.lastListingPlaystyle
        -- Blizzard_LFGVanilla_Listing.lua uses the same four enum choices in this dropdown.
        local styles = Enum.LFGEntryGeneralPlaystyle
        if
            self.active
            and tweaks.rememberListingPlaystyle
            and view.PlayStyleDropdown
            and playstyle ~= nil
            and playstyle ~= view.generalPlaystyle
            and styles
            and (playstyle == styles.Learning or playstyle == styles.FunRelaxed or playstyle == styles.FunSerious or playstyle == styles.Expert)
            and not C_LFGList.HasActiveEntryInfo()
        then
            LFGListingActivityView_OnPlayStyleSelectedInternal(view, playstyle)
            view.PlayStyleDropdown:SignalUpdate()
        end
    end)
end

local function reload()
    ReloadUI()
end

-- Same as the Keybindings settings' Quick Keybind Mode button; the frame is protected.
local function quickKeybind()
    if InCombatLockdown() then
        log:warn(ERR_NOT_IN_COMBAT)
        return
    end
    if not QuickKeybindFrame then
        return
    end
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsPanel:Close(true)
    end
    QuickKeybindFrame:Show()
end

---@param command string
---@param handler function
---@param enabled boolean
function module:SetShortcut(command, handler, enabled)
    local key = "ACECONSOLE_" .. command:upper()
    if self.active and enabled then
        if SlashCmdList[key] ~= handler then
            self:RegisterChatCommand(command, handler)
        end
    elseif SlashCmdList[key] == handler then
        -- Another addon may have replaced this command since we registered it.
        self:UnregisterChatCommand(command)
    end
end

function module:OnProfileRefresh()
    local tweaks = app.db.profile.tweaks
    self:SetShortcut("rl", reload, tweaks.reloadShortcut)
    self:SetShortcut("kb", quickKeybind, tweaks.quickKeybindShortcut)
    if self.active and tweaks.rememberListingPlaystyle and not self.lfgPlaystyleHooked then
        self:RegisterEvent("ADDON_LOADED", "HookListingPlaystyle")
        self:HookListingPlaystyle()
    else
        self:UnregisterEvent("ADDON_LOADED")
    end
end

function module:OnEnable()
    self.active = true
    self:OnProfileRefresh()
    -- The startup FPS preference is consumed by the optional custom display.
end

function module:OnDisable()
    self.active = false
    self:OnProfileRefresh()
end
