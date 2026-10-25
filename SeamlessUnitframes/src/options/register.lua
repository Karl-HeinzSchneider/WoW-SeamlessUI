---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0")
function module:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Unit Frames"], pages = app.optionPages })
end
local NATIVE = { player = true, pet = true, target = true, focus = true }
function module:OnEnable()
    local function refreshPosition()
        app.core:RefreshOptions(appName)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", refreshPosition)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", refreshPosition)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", refreshPosition)
    self.positionHooked = self.positionHooked or {}
    for _, entry in ipairs(app.unitFrames.list) do
        local frame = NATIVE[entry.key] and _G[entry.frameName]
        if frame and not self.positionHooked[frame] then
            self.positionHooked[frame] = true
            for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSettingFrameSize" }) do
                if frame[method] then
                    hooksecurefunc(frame, method, refreshPosition)
                end
            end
        end
    end
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "threatshownumeric" then
            self:Refresh()
        end
    end)
end

function module:OnProfileRefresh()
    app.core:RefreshEditModeSystemOptions()
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
