---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local syncOptions = {
    { "windows", L["Chat tabs"], L["Share tabs, names, order, font size, background, message types and channels."] },
    { "colors", L["Chat colors"], L["Share message and channel colors and class-colored names."] },
    {
        "channels",
        CHANNELS,
        L["Join the saved custom channels. Leaving stops other characters from joining but does not make them leave."],
    },
    {
        "position",
        L["Chat window position and size"],
        L["Share the main chat window's Edit Mode position and size. Characters using a preset layout keep their own position because presets cannot be changed."],
    },
}

local syncArgs = {
    status = {
        type = "description",
        order = 0,
        fontSize = "medium",
        name = function()
            local chat = app.db.profile.chat
            local status = chat
                    and (L["Saved by %s on %s."]):format(chat.savedBy or "?", date("%Y-%m-%d %H:%M", chat.savedAt or 0))
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
    syncArgs[entry[1]] = { type = "toggle", order = i, width = "full", name = entry[2], desc = entry[3] }
end
local syncGroup = {
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
    args = syncArgs,
}

local inputGroup = {
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

---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        if path[2] == "sync" then
            return app.dbDefaults.profile.sync[path[3]]
        end
        if path[2] == "input" then
            return app.dbDefaults.profile[path[3]]
        end
    end,
    defaults = {
        profile = {
            features = {},
            inputHistoryLines = 32, -- historyLines of ChatFrameEditBoxTemplate (ChatFrameEditBox.xml)
            persistInputHistory = true,
            -- What the profile's characters share (src/chat/sync.lua).
            sync = {
                windows = true, -- the chat tabs and windows, with the message types and channels each shows
                colors = true, -- chat colors and class-colored names
                channels = true, -- joined custom channels
                position = true, -- the main chat window's position and size (Edit Mode)
            },
        },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = { sync = syncGroup, input = inputGroup },
    },
}
