---@type string, SeamlessChat
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessChat.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessChat.Options]]

-- The tabs between General and Profiles. A feature picks one with `optionsTab` on its prototype.
---@type table<SeamlessChat.OptionsTab, { name: string, order: integer }>
local TABS = {
    messages = { name = L["Messages"], order = 10 },
    windows = { name = L["Windows"], order = 20 },
    buttons = { name = L["Buttons"], order = 30 },
    log = { name = L["Log"], order = 40 },
}

local syncOptions = {
    { "windows", L["Chat tabs"], L["Share tabs, names, order, font size, background, message types and channels."] },
    { "colors", L["Chat colors"], L["Share message and channel colors and class-colored names."] },
    {
        "channels",
        "Channels",
        L["Join the saved custom channels. Leaving stops other characters from joining but does not make them leave."],
    },
    {
        "position",
        L["Chat window position and size"],
        L["Share the main chat window's Edit Mode position and size. Characters using a preset layout keep their own position because presets cannot be changed."],
    },
}

local function SyncGroup()
    local args = {
        status = {
            type = "description",
            order = 0,
            fontSize = "medium",
            name = function()
                local chat = app.db.profile.chat
                local status = chat
                        and (L["Saved by %s on %s."]):format(
                            chat.savedBy or "?",
                            date("%Y-%m-%d %H:%M", chat.savedAt or 0)
                        )
                    or L["Nothing saved yet."]
                return status
                    .. (
                        L["\nCharacters using profile '%s' share this chat setup. Use separate profiles to keep their chat independent.\n"]
                    ):format(app.core.db:GetCurrentProfile())
            end,
        },
        save = {
            type = "execute",
            order = 100,
            name = L["Save now"],
            desc = L["Make this character's chat setup the one shared by this profile."],
            func = function()
                app.addon:OnSlashCommand("save")
            end,
        },
        apply = {
            type = "execute",
            order = 110,
            name = L["Apply now"],
            desc = L["Replace this character's chat setup with the profile's saved setup."],
            func = function()
                app.sync:Apply()
            end,
        },
    }
    for i, entry in ipairs(syncOptions) do
        args[entry[1]] = { type = "toggle", order = i, width = "full", name = entry[2], desc = entry[3] }
    end
    return {
        type = "group",
        inline = true,
        order = 10,
        name = L["Same chat on every character"],
        get = function(info)
            return app.db.profile.sync[info[#info]]
        end,
        set = function(info, value)
            app.db.profile.sync[info[#info]] = value
            if value then
                app.sync:Sync()
            end
        end,
        args = args,
    }
end

local function InputGroup()
    return {
        type = "group",
        inline = true,
        order = 20,
        name = L["Chat input"],
        get = function(info)
            return app.db.profile[info[#info]]
        end,
        set = function(info, value)
            app.db.profile[info[#info]] = value
            app.input:Refresh()
        end,
        args = {
            inputHistoryLines = {
                type = "range",
                order = 10,
                width = "double",
                name = L["Remembered messages"],
                desc = L["How many sent messages and commands the Up and Down keys bring back."],
                min = 1,
                max = 500,
                step = 1,
            },
            persistInputHistory = {
                type = "toggle",
                order = 20,
                width = "full",
                name = L["Keep them between sessions"],
                desc = L["Saves each chat window's input history per character. Temporary windows keep it for this session only."],
            },
        },
    }
end

-- A section per feature, on its tab, in TOC order.
local function FeatureTabs()
    local tabs = {}
    for key, tab in pairs(TABS) do
        tabs[key] = { order = tab.order, name = tab.name, args = {} }
    end
    for i, feature in ipairs(app.features.list) do
        local tab = assert(tabs[feature.optionsTab], "Unknown options tab of feature " .. feature.featureKey)
        tab.args[feature.featureKey] = app.core.FeatureGroup({
            name = feature.featureName,
            desc = feature.featureDesc,
            order = i,
            options = feature:GetOptions(),
            settings = function()
                return feature:GetSettings()
            end,
            toggled = function()
                feature:OnProfileRefresh()
            end,
            changed = function()
                if feature:IsEnabled() then
                    feature:Refresh()
                end
            end,
        })
    end
    return tabs
end

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = L["Chat"],
        general = { sync = SyncGroup(), input = InputGroup() },
        tabs = FeatureTabs(),
        db = app.db,
    })
end

---@param tab? SeamlessChat.OptionsTab
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end
