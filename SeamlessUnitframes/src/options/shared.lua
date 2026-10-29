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

---The shared layout setting, exposed on every affected frame.
---@return table
function app.UnitFrameLayoutOption()
    return {
        type = "select",
        order = 1,
        default = "current",
        name = L["Unit frame layout"],
        desc = L["Default uses the game's standard unit frame artwork and layout. Beta uses the artwork and layout from before update 70425. This setting applies to all unit frames. Changes made during combat apply when combat ends."],
        values = { current = L["Default"], legacy = L["Beta"] },
        sorting = { "current", "legacy" },
        get = function()
            return app.db.profile.layout
        end,
        set = function(_, value)
            app.db.profile.layout = value
            app.legacyLayout:Refresh()
            app.core:RefreshOptions(appName)
            app.core:RefreshEditModeSystemOptions()
        end,
    }
end
