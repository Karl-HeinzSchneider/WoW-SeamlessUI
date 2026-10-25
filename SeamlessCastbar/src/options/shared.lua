---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The player bar is the client's Edit Mode cast bar system: its Position and scale group reads
-- and writes the active layout like the native settings, with Bar Size as the scale. While the
-- bar is locked to the player frame, the player frame places it, so position is unavailable.
function app.PlayerCastbarPosition()
    local settings = Enum.EditModeCastBarSetting
    if not settings then
        return nil
    end
    local service = app.core:GetFramePositionService()
    local function getBar()
        return PlayerCastingBarFrame
    end
    local function getMovableBar()
        local frame = getBar()
        local locked = frame and service:ReadSetting(frame, settings.LockToPlayerFrame)
        if locked and locked ~= 0 then
            return nil
        end
        return frame
    end
    return app.core:GetNativePositionOptions(getMovableBar, app.core:GetNativeSettingScale(getBar, settings.BarSize))
end
