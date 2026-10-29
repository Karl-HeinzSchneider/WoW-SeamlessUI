---@type string, SeamlessUI
local _, app = ...
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
    defaults = {
        profile = {
            hideMinimapDayNight = false,
            minimap = {
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
