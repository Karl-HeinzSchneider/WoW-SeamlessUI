---@type string, SeamlessUI
local _, app = ...

---@class SeamlessUI.BlizzardEditMode : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("BlizzardEditMode", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.BlizzardEditMode]]
app.blizzardEditMode = module
module:SetEnabledState(false)

local frames = {
    { key = "player", name = "Player frame", index = "Player" },
    { key = "target", name = "Target frame", index = "Target" },
    { key = "pet", name = "Pet frame", index = "Pet" },
    { key = "focus", name = "Focus frame", index = "Focus" },
}
local panel, title

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
    panel:SetHeight(100)
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
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -10)
    text:SetWordWrap(true)
    text:SetText("Edit Mode extension enabled. Additional controls will be added here.")
end

function module:RefreshPanel()
    hidePanel()
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
    if not system or system.system ~= Enum.EditModeSystem.UnitFrame then
        return
    end
    for _, spec in ipairs(frames) do
        local index = Enum.EditModeUnitFrameSystemIndices[spec.index]
        if index and system.systemIndex == index and settings().frames[spec.key].enabled then
            ensurePanel()
            title:SetText("SeamlessUI - " .. spec.name)
            panel:SetFrameLevel(dialog:GetFrameLevel() + 10)
            panel:Show()
            return
        end
    end
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
            name = "Enable Blizzard Edit Mode extensions",
            desc = "Adds a SeamlessUI window below the selected Blizzard frame's Edit Mode settings. Turn off to disable all extensions.",
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
    for order, spec in ipairs(frames) do
        local key = spec.key
        args[key] = {
            type = "group",
            inline = true,
            order = order + 10,
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
                    name = "Extend Edit Mode",
                    desc = "Show the SeamlessUI extension when this frame is selected in Edit Mode. Turn off if this frame causes issues.",
                },
                addPosition = {
                    type = "toggle",
                    order = 2,
                    name = "Add position",
                    desc = "Reserved for future position controls. This setting has no effect yet.",
                    disabled = function()
                        return not settings().enabled or not settings().frames[key].enabled
                    end,
                },
                addMoreOptions = {
                    type = "toggle",
                    order = 3,
                    name = "Add more options",
                    desc = "Reserved for future frame options. This setting has no effect yet.",
                    disabled = function()
                        return not settings().enabled or not settings().frames[key].enabled
                    end,
                },
            },
        }
    end
    return { order = 30, name = "Blizzard Edit Mode Extensions", args = args }
end
