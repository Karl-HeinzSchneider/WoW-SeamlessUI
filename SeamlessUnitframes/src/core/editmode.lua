---@type string, SeamlessUnitframes
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Each unit frame's style rows (style.lua) under a collapsible Style header in its Edit Mode
-- settings, writing the same profile as its options tab. The section sits in SeamlessUI's extended
-- window below the frame's own settings (SeamlessUI draws it); it is never a window of its own.
-- Frames without an Edit Mode system (target of target, target of focus) show their rows in the
-- section of the frame they belong to.

---@class SeamlessUnitframes.EditMode : AceModule
local module = {}
app.editMode = app.addon:NewModule("EditMode", module) --[[@as SeamlessUnitframes.EditMode]]

local registered = false

function module:OnEnable()
    local indices = Enum.EditModeUnitFrameSystemIndices
    if registered or not (Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame and indices) then
        app.core:RefreshEditModeSystemOptions()
        return
    end
    registered = true
    for _, entry in ipairs(app.unitFrames.list) do
        local systemIndex = entry.system and indices[entry.system]
        if systemIndex then
            app.core:RegisterEditModeSystemOptions(appName .. "." .. entry.key, {
                system = Enum.EditModeSystem.UnitFrame,
                systemIndex = systemIndex,
                name = L["Style"],
                key = "unitframe-style",
                enabled = function()
                    return app.addon:IsEnabled()
                end,
                options = app.StyleOptions(entry),
            })
        end
    end
end

function module:OnDisable()
    app.core:RefreshEditModeSystemOptions()
end
