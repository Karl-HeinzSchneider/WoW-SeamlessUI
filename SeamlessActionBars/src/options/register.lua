---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.optionFrameGetters = {
    function()
        return _G["BagsBar"]
    end,
    function()
        return _G["MainActionBar"]
    end,
    function()
        return _G["MultiBarBottomLeft"]
    end,
    function()
        return _G["MultiBarBottomRight"]
    end,
    function()
        return _G["MultiBarRight"]
    end,
    function()
        return _G["MultiBarLeft"]
    end,
    function()
        return _G["MultiBar5"]
    end,
    function()
        return _G["MultiBar6"]
    end,
    function()
        return _G["MultiBar7"]
    end,
    function()
        return _G["MainStatusTrackingBarContainer"]
    end,
    function()
        return _G["SecondaryStatusTrackingBarContainer"]
    end,
    function()
        return _G["PetActionBar"]
    end,
    function()
        return _G["MainMenuBarVehicleLeaveButton"]
    end,
    function()
        return _G["MicroMenuContainer"]
    end,
    function()
        return app.EndCapFrame(app.endCaps[1])
    end,
    function()
        return app.EndCapFrame(app.endCaps[2])
    end,
}
local options = app.addon:NewModule("Options", "AceEvent-3.0")
function options:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Action Bars"], pages = app.optionPages })
end
-- Position and scale live in the native layout: redraw when it changes outside these options.
function options:OnEnable()
    local function refreshPosition()
        app.core:RefreshOptions(appName)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", refreshPosition)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", refreshPosition)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", refreshPosition)
    self.positionHooked = self.positionHooked or {}
    for _, getFrame in ipairs(app.optionFrameGetters) do
        local frame = getFrame()
        if frame and not self.positionHooked[frame] then
            self.positionHooked[frame] = true
            for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSetting" }) do
                if frame[method] then
                    hooksecurefunc(frame, method, refreshPosition)
                end
            end
        end
    end
end
