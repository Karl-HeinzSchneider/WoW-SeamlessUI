---@type string, SeamlessUnitframes
local appName, app = ...

-- Each unit frame's page, drawn by Core in Edit Mode from its declaration and writing the same
-- profile as its options tab. The sections sit in SeamlessUI's extended window below the frame's own
-- settings (SeamlessUI draws it); it is never a window of its own. Target of Target and Target of
-- Focus show their pages on their stand-ins (mover.lua).

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
                name = entry.name,
                page = { addon = appName, key = entry.key },
                enabled = function()
                    return app.addon:IsEnabled()
                end,
            })
        end
    end
end

function module:OnDisable()
    app.core:RefreshEditModeSystemOptions()
end
