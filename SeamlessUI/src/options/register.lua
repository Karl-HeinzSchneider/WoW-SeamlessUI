---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessUI.Options]]
function module:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["UI"], pages = app.optionPages })
end
-- Native layout edits and combat availability can change while the page is open.
function module:OnEnable()
    local function refresh()
        app.core:RefreshOptions(appName)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", refresh)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", refresh)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", refresh)
    local function hookMinimap()
        local frame = MinimapCluster
        if frame and self.positionHooked ~= frame then
            self.positionHooked = frame
            for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSetting" }) do
                if frame[method] then
                    hooksecurefunc(frame, method, refresh)
                end
            end
        end
    end
    self:RegisterEvent("ADDON_LOADED", hookMinimap)
    hookMinimap()
end
---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end
