---@type string, SeamlessUI
local _, app = ...

---@class SeamlessUI.Minimap : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("Minimap", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.Minimap]]
app.minimap = module

function module:OnInitialize()
    if not Enum.EditModeSystem or not Enum.EditModeSystem.Minimap then
        return
    end
    local style = app.optionPages.minimap.config.args.style
    local option = style.args.hideMinimapDayNight
    app.core:RegisterEditModeSystemOptions("SeamlessUI:minimap", {
        system = Enum.EditModeSystem.Minimap,
        name = style.name,
        key = "SeamlessUI:minimap:style",
        enabled = function()
            return self:IsEnabled() and app.addon:IsEnabled()
        end,
        options = {
            {
                key = "hideMinimapDayNight",
                type = option.type,
                name = option.name,
                default = option.default,
                get = option.get,
                set = function(value)
                    option.set(nil, value)
                end,
            },
        },
    })
end

function module:Apply()
    local frame = MinimapCluster and MinimapCluster.DielFrame
    if not frame then
        return
    end
    if not self:IsHooked(frame, "OnShow") then
        self:SecureHookScript(frame, "OnShow", "Apply")
    end
    if app.db.profile.hideMinimapDayNight then
        if frame:IsShown() then
            self.hiddenFrame = frame
            frame:Hide()
        end
    elseif self.hiddenFrame then
        self.hiddenFrame = nil
        frame:Show()
    end
end

function module:OnEnable()
    app.core:RefreshEditModeSystemOptions()
    self:RegisterEvent("ADDON_LOADED", "Apply")
    self:Apply()
end

function module:OnDisable()
    app.core:RefreshEditModeSystemOptions()
    self:UnhookAll()
    self:UnregisterAllEvents()
    if self.hiddenFrame then
        local frame = self.hiddenFrame
        self.hiddenFrame = nil
        frame:Show()
    end
end

function module:OnProfileRefresh()
    if self:IsEnabled() and IsLoggedIn() then
        self:Apply()
    end
end
