---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Frames with their own Edit Mode position and Frame Size get a native Position and scale group.
local NATIVE = { player = true, pet = true, target = true, focus = true }

---The frame's Position and scale group, or nil when it has none.
---@param entry SeamlessUnitframes.UnitFrame
---@return table?
function app.UnitFramePositionOptions(entry)
    if not NATIVE[entry.key] then
        return app.totPosition:GetOptions(entry.key)
    end
    local function getFrame()
        return _G[entry.frameName]
    end
    return app.core:GetNativePositionOptions(
        getFrame,
        app.core:GetNativeSettingScale(getFrame, Enum.EditModeUnitFrameSetting.FrameSize)
    )
end
