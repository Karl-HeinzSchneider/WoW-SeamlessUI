---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
-- Each cast bar's page, drawn by Core in Edit Mode from its declaration, writing the same profile
-- as its tab. The player bar is the client's own Edit Mode system: its sections sit in the extended
-- window below the cast bar's settings (SeamlessUI draws it), and its Size rows join that window's
-- Size section. Target and focus bars have no system of their own; their previews (preview.lua)
-- show the same page in the suite's settings window.

local registered = false

-- Called once from OnEnable; the client's cast bar system must exist.
function app.RegisterEditMode()
    if registered or not (Enum.EditModeSystem and Enum.EditModeSystem.CastBar) then
        return
    end
    registered = true
    app.core:RegisterEditModeSystemOptions(appName, {
        system = Enum.EditModeSystem.CastBar,
        name = app.optionPages.player.config.name,
        page = { addon = appName, key = "player" },
        enabled = function()
            return app.addon:IsEnabled()
        end,
    })
end
