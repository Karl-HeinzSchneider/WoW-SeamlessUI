---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return MinimapCluster
end
local rotation = Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.RotateMinimap
local nativeSettings = app.core:GetFramePositionService()

local function visibilityOption(key, name, order)
    local function settings()
        return key == "hideMinimapDayNight" and app.db.profile or app.db.profile.minimap
    end
    return {
        type = "toggle",
        order = order,
        width = "full",
        name = name,
        desc = key == "square" and L["Uses the round minimap while Rotate Minimap is enabled."] or nil,
        default = false,
        get = function()
            return settings()[key]
        end,
        set = function(_, value)
            settings()[key] = value
            app.minimap:OnProfileRefresh()
        end,
    }
end

local position, size = app.core:GetNativePositionOptions(getFrame)
---@type SeamlessCore.SettingsPage
app.optionPages.minimap = {
    defaults = {
        profile = {
            hideMinimapDayNight = false,
            minimap = {
                square = false,
                hideAddonCompartment = false,
                hideTracking = false,
                hideCalendar = false,
                hideClock = false,
                hideZoneText = false,
                hideHeader = false,
            },
        },
    },
    config = {
        type = "group",
        name = L["Minimap"],
        order = 40,
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        args = {
            style = {
                type = "group",
                inline = true,
                name = L["Style"],
                order = 20,
                args = {
                    square = visibilityOption("square", L["Square minimap"], 1),
                    rotateMinimap = {
                        type = "toggle",
                        order = 2,
                        width = "full",
                        name = L["Rotate minimap"],
                        blizzard = true,
                        editMode = true,
                        -- The Edit Mode preset layouts' RotateMinimap value.
                        default = function()
                            local value = rotation and nativeSettings:GetDefaultSetting(getFrame(), rotation)
                            if value ~= nil then
                                return value == 1
                            end
                        end,
                        disabled = function()
                            return not rotation or not nativeSettings:CanEdit(getFrame())
                        end,
                        get = function()
                            return rotation and nativeSettings:ReadSetting(getFrame(), rotation) == 1 or false
                        end,
                        set = function(_, value)
                            if not rotation then
                                return
                            end
                            local ok, err = nativeSettings:ApplySetting(getFrame(), rotation, value and 1 or 0)
                            if not ok and err then
                                app.logger:warn("%s", err)
                            end
                            app.core:RefreshOptions(appName)
                            app.core:RefreshEditModeSystemOptions()
                        end,
                    },
                    hideMinimapDayNight = visibilityOption(
                        "hideMinimapDayNight",
                        L["Hide minimap day/night indicator"],
                        10
                    ),
                    hideAddonCompartment = visibilityOption(
                        "hideAddonCompartment",
                        L["Hide addon compartment button"],
                        20
                    ),
                    hideTracking = visibilityOption("hideTracking", L["Hide tracking button"], 30),
                    hideCalendar = visibilityOption("hideCalendar", L["Hide calendar button"], 40),
                    hideClock = visibilityOption("hideClock", L["Hide clock"], 45),
                    hideZoneText = visibilityOption("hideZoneText", L["Hide zone text button"], 50),
                    hideHeader = visibilityOption("hideHeader", L["Hide complete minimap header"], 60),
                },
            },
            position = position,
            size = size,
        },
    },
}
