---@type string, SeamlessUI
local _, app = ...

-- Draws the sections other addons register with Core's RegisterEditModeSystemOptions in the
-- extended window, through Core's shared row renderer.

---@class SeamlessUI.SystemOptions
local systemOptions = {}
app.systemOptions = systemOptions

---Lay out the selected system's sections in parent from y down; returns the bottom.
---@param parent table The extended window.
---@param system table The selected system frame.
---@param y number Top offset of the first section.
---@param spaced boolean Whether something sits above, so the first header needs a gap.
---@param changed fun() Redraws the window after a click.
---@return number bottom
function systemOptions:Layout(parent, system, y, spaced, changed)
    local sections = {}
    for _, spec in ipairs(app.core:GetEditModeSystemOptions(system)) do
        sections[#sections + 1] = {
            id = spec.id,
            name = spec.name,
            key = "settings:" .. (spec.key or spec.name),
            options = spec.options,
        }
    end
    return app.core:LayoutEditModeSections(parent, sections, y, spaced, changed)
end
