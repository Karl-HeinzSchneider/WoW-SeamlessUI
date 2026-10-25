---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local self = app
local function Selected()
    return app.archive:Get(app.historySelection)
end
---@type SeamlessCore.SettingsPage
app.optionPages.history = {
    tooltip = function(path)
        if path[#path] == "retention" then
            return 50, true
        end
        if path[#path] == "pin" then
            return false, true
        end
        return nil, true
    end,
    defaults = {},
    config = {
        type = "group",
        name = L["History"],
        order = 60,
        hidden = not app.combatService.saveSessions,
        args = {
            info = {
                type = "description",
                order = 1,
                name = L["Completed public fights are saved per character through reload/relog. Hidden windows still collect. Reloading during restricted combat may leave incomplete data. The oldest saved segment is deleted before adding a segment above your limit. Pinned segments also count toward the limit. The hard upper limit is 1,000 segments.\nSelect fights from a window's session menu.\n"],
            },
            retention = {
                type = "range",
                name = L["Maximum saved segments"],
                order = 10,
                min = 1,
                max = self.archive.maxSegments,
                step = 1,
                get = function()
                    return self.archive.db.retention
                end,
                set = function(_, value)
                    self.combatService:SetSegmentLimit(value)
                end,
            },
            fight = {
                type = "select",
                name = L["Saved fight"],
                order = 20,
                width = "full",
                values = function()
                    local values = {}
                    for _, entry in ipairs(self.combatService:ListSessions()) do
                        if entry.archiveID then
                            values[tostring(entry.archiveID)] = self.combatService:Describe(entry)
                        end
                    end
                    return values
                end,
                get = function()
                    return self.historySelection and tostring(self.historySelection)
                end,
                set = function(_, value)
                    self.historySelection = tonumber(value)
                end,
            },
            status = {
                type = "description",
                order = 25,
                name = function()
                    local fight = Selected()
                    if not fight then
                        return L["Select a saved fight."]
                    end
                    return fight.complete and L["All supported categories and source details captured."]
                        or L["Incomplete capture: some categories or source details are missing."]
                end,
            },
            pin = {
                type = "toggle",
                name = L["Pin selected fight"],
                order = 30,
                disabled = function()
                    return not Selected()
                end,
                get = function()
                    local fight = Selected()
                    return fight and fight.pinned or false
                end,
                set = function(_, value)
                    if Selected() and Selected().pinned ~= value then
                        self.combatService:Pin(self.historySelection)
                    end
                end,
            },
            delete = {
                type = "execute",
                name = L["Delete selected fight"],
                order = 50,
                confirm = true,
                disabled = function()
                    return not Selected()
                end,
                func = function()
                    self.combatService:Delete(self.historySelection)
                    self.historySelection = nil
                end,
            },
            deleteOlder = {
                type = "execute",
                name = L["Delete segments older than selected"],
                order = 55,
                confirm = L["Delete all saved segments older than the selected fight, including pinned segments?"],
                disabled = function()
                    return not Selected()
                end,
                func = function()
                    self.combatService:DeleteOlderSegments(self.historySelection)
                end,
            },
            clear = {
                type = "execute",
                name = L["Clear saved history"],
                order = 60,
                confirm = L["Delete all saved fights, including pinned fights? Blizzard tracking is not reset."],
                func = function()
                    self.combatService:ClearHistory()
                    self.historySelection = nil
                end,
            },
        },
    },
}
