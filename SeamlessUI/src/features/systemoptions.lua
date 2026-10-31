---@type string, SeamlessUI
local _, app = ...

-- The sections other addons register with Core's RegisterEditModeSystemOptions, for the extended
-- window, which draws them with Core's shared row renderer.

---@class SeamlessUI.SystemOptions
local systemOptions = {}
app.systemOptions = systemOptions

---The selected system's registered sections, for Core's LayoutEditModeSections.
---@param system table The selected system frame.
---@return SeamlessCore.EditModeSection[]
function systemOptions:GetSections(system)
    return app.core:GetEditModeSystemSections(system)
end
