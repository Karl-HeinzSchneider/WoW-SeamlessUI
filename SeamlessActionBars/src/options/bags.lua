---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["BagsBar"]
end
local service = app.core:GetFramePositionService()
local settings = Enum.EditModeBagsSetting or {}
local orientation = Enum.BagsOrientation or {}
local direction = Enum.BagsDirection or {}
local scale = settings.Size and app.core:GetNativeSettingScale(getFrame, settings.Size)

local function nativeOption(key, name, order)
    local setting = settings[key]
    return {
        name = name,
        order = order,
        editMode = true,
        blizzard = true,
        default = function()
            return setting and service:GetDefaultSetting(getFrame(), setting)
        end,
        disabled = function()
            return not setting or not service:CanEdit(getFrame()) or service:ReadSetting(getFrame(), setting) == nil
        end,
        get = function()
            return setting and service:ReadSetting(getFrame(), setting)
        end,
        set = function(_, value)
            local ok, err = service:ApplySetting(getFrame(), setting, value)
            if not ok and err then
                app.core.logger:warn("%s", err)
            end
            app.core:RefreshOptions(appName)
        end,
    }
end

local args = {}
args.retailStyle = {
    type = "toggle",
    name = L["Retail bag button style"],
    desc = L["Use round bag buttons and a larger backpack, including the keyring and reagent bag. Disabled until you enable it."],
    order = 5,
    width = "full",
    default = false,
    get = function()
        return app.db.profile.bags.retailStyle
    end,
    set = function(_, value)
        app.db.profile.bags.retailStyle = value
        app.RefreshBagStyle()
    end,
}
if orientation.Horizontal and orientation.Vertical then
    args.orientation = nativeOption("Orientation", L["Orientation"], 10)
    args.orientation.type = "select"
    args.orientation.values = {
        [orientation.Horizontal] = L["Horizontal"],
        [orientation.Vertical] = L["Vertical"],
    }
    args.orientation.sorting = { orientation.Horizontal, orientation.Vertical }
end
if direction.Left and direction.Right and direction.Up and direction.Down then
    args.direction = nativeOption("Direction", L["Bag direction"], 20)
    args.direction.type = "select"
    args.direction.values = function()
        if settings.Orientation and service:ReadSetting(getFrame(), settings.Orientation) == orientation.Vertical then
            return { [direction.Up] = L["Up"], [direction.Down] = L["Down"] }
        end
        return { [direction.Left] = L["Left"], [direction.Right] = L["Right"] }
    end
end

---@type SeamlessCore.SettingsPage
app.optionPages.bags = {
    defaults = { profile = { bags = { retailStyle = false } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Bags"],
        order = 140,
        hidden = function()
            return getFrame() == nil
        end,
        args = {
            layout = { type = "group", inline = true, name = L["Style"], order = 20, args = args },
            position = app.core:GetNativePositionOptions(getFrame, scale),
        },
    },
}
