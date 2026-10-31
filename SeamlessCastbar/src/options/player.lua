---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end
local function resetSize()
    local settings = app.db.profile.player
    for _, key in ipairs({ "width", "height", "scale", "iconSize" }) do
        settings[key] = app.PlayerSizeDefault(key)
    end
    refresh()
    app.core:RefreshOptions(appName)
end
local position, size = app.PlayerCastbarPosition()
if position then
    position.order = 5
    size.order = 6
end
size = size or { type = "group", inline = true, name = L["Size"], order = 6, args = {}, editModeSize = true }
-- Every control below replaces the native layout binding with a profile setting.
size.layoutStored = false
size.args.scale = {
    type = "range",
    order = 0,
    name = L["Scale"],
    min = 0.5,
    max = 3,
    step = 0.01,
    layoutStored = false,
    get = function()
        return app.db.profile.player.scale or app.PlayerSizeDefault("scale")
    end,
    set = function(_, value)
        app.db.profile.player.scale = value
        refresh()
    end,
}
size.args.width = {
    type = "range",
    order = 6,
    name = L["Width"],
    min = 10,
    max = 300,
    step = 1,
    get = function()
        return app.db.profile.player.width or app.PlayerSizeDefault("width")
    end,
    set = function(_, value)
        app.db.profile.player.width = value
        refresh()
    end,
}
size.args.height = {
    type = "range",
    order = 7,
    name = L["Height"],
    min = 8,
    max = 32,
    step = 1,
    get = function()
        return app.db.profile.player.height or app.PlayerSizeDefault("height")
    end,
    set = function(_, value)
        app.db.profile.player.height = value
        refresh()
    end,
}
size.args.width.layoutStored = false
size.args.height.layoutStored = false
size.args.iconSize = {
    type = "range",
    order = 8,
    name = L["Icon size"],
    min = 8,
    max = 64,
    step = 1,
    layoutStored = false,
    get = function()
        return app.db.profile.player.iconSize or app.PlayerSizeDefault("iconSize")
    end,
    set = function(_, value)
        app.db.profile.player.iconSize = value
        refresh()
    end,
}
size.args.resetSize = {
    type = "execute",
    order = 9,
    name = L["Reset to default size"],
    layoutStored = false,
    hidden = function()
        return app.core:GetEditModeLibrary():IsInEditMode()
    end,
    func = resetSize,
}
---@type SeamlessCore.SettingsPage
app.optionPages.player = {
    tooltip = function(path)
        if
            path[2] == "size"
            and (path[3] == "width" or path[3] == "height" or path[3] == "scale" or path[3] == "iconSize")
        then
            return app.PlayerSizeDefault(path[3])
        end
        local value = app.core:GetOptionDefault(app.dbDefaults.profile, path)
        if type(value) == "table" then
            return value.enabled
        end
        return value
    end,
    defaults = {
        profile = {
            player = {
                -- PlayerCastingBarFrameTemplate/CastingBarFrameBaseTemplate in the client XML;
                -- Bar Size defaults to 100% in Edit Mode's setting display info.
                width = 208,
                height = 11,
                scale = 1,
                iconSize = 16,
                castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
                rank = { enabled = true },
                ticks = { enabled = true },
                hold = { enabled = false, success = 0.2, interrupt = 1 },
                icon = { enabled = true },
            },
        },
    },
    config = {
        editModeFrame = function()
            return PlayerCastingBarFrame
        end,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
            { name = L["Reset to default size"], click = resetSize },
        }),
        type = "group",
        name = L["Player"],
        order = 10,
        args = {
            position = position,
            size = size,
            icon = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.player.icon
                end,
                toggled = refresh,
                changed = refresh,

                order = 40,
                name = L["Spell icon"],
                desc = L["Show the spell icon beside the player cast bar when it is not locked to the player frame."],
            },

            castTime = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.player.castTime
                end,
                toggled = refresh,
                changed = refresh,

                order = 10,
                name = L["Cast time"],
                desc = L["Change how the player cast bar's cast time reads. Show it with Show Cast Time in the cast bar's Edit Mode settings."],
                args = {
                    format = {
                        type = "select",
                        order = 1,
                        name = L["Cast time format"],
                        values = app.castTimeFormats,
                        sorting = app.castTimeFormatOrder,
                    },
                    decimals = { type = "range", order = 2, name = L["Decimals"], min = 0, max = 2, step = 1 },
                },
            },
            rank = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.player.rank
                end,
                toggled = refresh,
                changed = refresh,

                order = 20,
                name = L["Spell rank"],
                desc = L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
            },
            ticks = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.player.ticks
                end,
                toggled = refresh,
                changed = refresh,

                order = 30,
                name = L["Channel ticks"],
                desc = L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
            },
            hold = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.player.hold
                end,
                toggled = refresh,
                changed = refresh,

                order = 50,
                name = L["Hold time"],
                desc = L["How long a cast bar stays before it fades out."],
                args = {
                    success = {
                        type = "range",
                        order = 1,
                        name = L["After a finished cast"],
                        desc = L["Seconds. The game uses 0.2."],
                        min = 0,
                        max = 3,
                        step = 0.1,
                    },
                    interrupt = {
                        type = "range",
                        order = 2,
                        name = L["After an interrupt"],
                        desc = L["Seconds. The game uses 1."],
                        min = 0.1,
                        max = 5,
                        step = 0.1,
                    },
                },
            },
        },
    },
}
