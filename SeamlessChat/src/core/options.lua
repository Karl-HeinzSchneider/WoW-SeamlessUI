---@type string, SeamlessChat
local appName, app = ...

---@class SeamlessChat.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessChat.Options]]

local syncOptions = {
    { "windows", "Chat tabs", "Share tabs, names, order, font size, background, message types and channels." },
    { "colors", "Chat colors", "Share message and channel colors and class-colored names." },
    {
        "channels",
        "Channels",
        "Join the saved custom channels. Leaving stops other characters from joining but does not make them leave.",
    },
    {
        "position",
        "Chat window position and size",
        "Share the main chat window's Edit Mode position and size. Characters using a preset layout keep their own position because presets cannot be changed.",
    },
}

function module:OnInitialize()
    app.core:RegisterOptions(appName, "Chat", function(panel)
        panel:Header("Sync between characters")
        panel:Description("Chat sync status", function()
            local chat = app.db.profile.chat
            local status = chat
                    and ("Saved by %s on %s."):format(chat.savedBy or "?", date("%Y-%m-%d %H:%M", chat.savedAt or 0))
                or "Nothing saved yet."
            return status
                .. ("\nCharacters using profile '%s' share this chat setup. Use separate profiles to keep their chat independent."):format(
                    app.db:GetCurrentProfile()
                )
        end)
        for _, entry in ipairs(syncOptions) do
            local key = entry[1]
            panel:Checkbox({
                id = "sync." .. key,
                name = entry[2],
                tooltip = entry[3],
                default = app.dbDefaults.profile.sync[key],
                get = function()
                    return app.db.profile.sync[key]
                end,
                set = function(value)
                    app.db.profile.sync[key] = value
                    if value then
                        app.sync:Sync()
                    end
                end,
            })
        end
        panel:Button("Save this character's chat setup", "Save now", function()
            app.addon:OnSlashCommand("save")
        end, "Make this character's chat setup the one shared by this profile.")
        panel:Button("Apply the saved chat setup", "Apply now", function()
            app.sync:Apply()
        end, "Replace this character's chat setup with the profile's saved setup.")
        panel:Header("Chat input")
        panel:Slider({
            id = "inputHistoryLines",
            name = "Chat input history",
            tooltip = "Number of sent messages and nonsecure commands remembered for Up/Down recall.",
            default = app.dbDefaults.profile.inputHistoryLines,
            min = 1,
            max = 500,
            step = 1,
            get = function()
                return app.db.profile.inputHistoryLines
            end,
            set = function(value)
                app.db.profile.inputHistoryLines = value
                app.input:Refresh()
            end,
        })
        panel:Checkbox({
            id = "persistInputHistory",
            name = "Keep chat input history between sessions",
            tooltip = "Save regular chat-window input history per character. Temporary windows keep history for this session only.",
            default = app.dbDefaults.profile.persistInputHistory,
            get = function()
                return app.db.profile.persistInputHistory
            end,
            set = function(value)
                app.db.profile.persistInputHistory = value
                app.input:Refresh()
            end,
        })
        for _, feature in ipairs(app.features.list) do
            local key = feature.featureKey
            local prefix = "features." .. key
            local enabledID = prefix .. ".enabled"
            panel:Header(feature.featureName)
            panel:Checkbox({
                id = enabledID,
                name = "Enable " .. feature.featureName,
                tooltip = feature.featureDesc,
                default = app.dbDefaults.profile.features[key].enabled,
                get = function()
                    return feature:GetSettings().enabled
                end,
                set = function(value)
                    feature:GetSettings().enabled = value
                    feature:OnProfileRefresh()
                end,
            })
            panel:Options({
                id = prefix,
                name = feature.featureName,
                options = feature:GetOptions(),
                defaults = app.dbDefaults.profile.features[key],
                get = function()
                    return feature:GetSettings()
                end,
                changed = function()
                    if feature:IsEnabled() then
                        feature:Refresh()
                    end
                end,
                enabled = function()
                    return feature:GetSettings().enabled
                end,
                dependencies = { enabledID },
                tags = { feature.featureName },
            })
        end
        panel:Profiles(app.db)
    end)
end

function module:Open()
    app.core:OpenOptions(appName)
end
function module:Refresh()
    app.core:RefreshOptions(appName)
end
function module:OnProfileRefresh()
    self:Refresh()
end
