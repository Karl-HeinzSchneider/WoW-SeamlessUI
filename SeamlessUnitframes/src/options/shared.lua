---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Frames with their own Edit Mode position and Frame Size get a native Position and Size groups.
local NATIVE = { player = true, pet = true, target = true, focus = true }

---The frame's Position and Size groups, or nil when it has none.
---@param entry SeamlessUnitframes.UnitFrame
---@return table?
function app.UnitFramePositionOptions(entry)
    if not NATIVE[entry.key] then
        return app.totPosition:GetOptions(entry.key)
    end
    local function getFrame()
        return _G[entry.frameName]
    end
    return app.core:GetNativePositionOptions(getFrame)
end

---The shared layout setting, exposed on every affected frame.
---@return table
function app.UnitFrameLayoutOption()
    return {
        type = "select",
        order = 1,
        default = "current",
        name = L["Unit frame layout"],
        desc = L["Default uses the game's standard unit frame artwork and layout. Beta uses the artwork and layout from before update 70425. Beta (rounded) uses the same layout with a round player portrait border. This setting applies to all unit frames. Changes made during combat apply when combat ends."],
        values = { current = L["Default"], legacy = L["Beta"], legacyRounded = L["Beta (rounded)"] },
        sorting = { "current", "legacy", "legacyRounded" },
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

---The client-wide status text proxy, matching Blizzard's Interface dropdown.
---@return table
function app.UnitFrameStatusTextOption()
    return {
        type = "select",
        order = 32,
        name = L["Status Text"],
        desc = L["Controls health and power text using Blizzard's client-wide setting. Changing this on any frame changes it for all supported frames."],
        blizzard = true,
        -- Blizzard_SettingsDefinitions_Frame/Interface.lua's PROXY_STATUS_TEXT
        -- declares defaultValue = 4 (NONE), independently of either live CVar.
        default = "NONE",
        values = { NUMERIC = L["Numeric Value"], PERCENT = L["Percentage"], BOTH = L["Both"], NONE = L["None"] },
        sorting = { "NUMERIC", "PERCENT", "BOTH", "NONE" },
        get = function()
            return GetCVar("statusTextDisplay")
        end,
        set = function(_, value)
            SetCVar("statusTextDisplay", value)
            SetCVar("statusText", value == "NONE" and "0" or "1")
            app.core:RefreshOptions(appName)
            app.core:RefreshEditModeSystemOptions()
        end,
    }
end
