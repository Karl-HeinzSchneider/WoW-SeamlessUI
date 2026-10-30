---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return MinimapCluster
end
local setting = Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.Size
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)

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

---@type SeamlessCore.SettingsPage
app.optionPages.minimap = {
    tooltip = function(path)
        if path[#path] == "rotateMinimap" then
            return app.core:GetCVarOptionInfo("rotateMinimap")
        end
    end,
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
                        get = function()
                            return GetCVarBool("rotateMinimap")
                        end,
                        set = function(_, value)
                            SetCVar("rotateMinimap", value and "1" or "0")
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
            position = app.core:GetNativePositionOptions(getFrame, scale),
        },
    },
}
