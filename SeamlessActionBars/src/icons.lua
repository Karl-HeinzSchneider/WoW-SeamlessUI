---@type string, SeamlessActionBars
local _, app = ...

-- Action button icon colors. The client already greys out unusable actions and shades actions
-- lacking mana; this replaces that shade with a configurable one and adds a color for actions
-- out of range of the current target. Range wins over mana.

---@type table<CheckButton, true>
local tinted = setmetatable({}, { __mode = "k" })

---@param value any
local function known(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- The colors `ActionBarActionButtonMixin:UpdateUsable` gives the icon, restored when a tint ends.
---@param icon Texture
---@param isUsable boolean
---@param notEnoughMana boolean
local function nativeColor(icon, isUsable, notEnoughMana)
    if isUsable then
        icon:SetVertexColor(1, 1, 1)
    elseif notEnoughMana then
        icon:SetVertexColor(0.5, 0.5, 1)
    else
        icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

---@param button CheckButton
function app.PaintIcon(button)
    local icon, action = button.icon, button.action
    if not icon or not action or not C_ActionBar.HasAction(action) then
        tinted[button] = nil
        return
    end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(action)
    if not known(isUsable) or not known(notEnoughMana) then
        return
    end
    local profile = app.db.profile
    local color
    if profile.range.enabled then
        -- nil when the action has no range or there is no target.
        local inRange = C_ActionBar.IsActionInRange(action)
        if known(inRange) and not inRange then
            color = profile.range.color
        end
    end
    if not color and profile.mana.enabled and not isUsable and notEnoughMana then
        color = profile.mana.color
    end
    if color then
        icon:SetVertexColor(color.r, color.g, color.b)
        tinted[button] = true
    elseif tinted[button] then
        nativeColor(icon, isUsable, notEnoughMana)
        tinted[button] = nil
    end
end

---@param button CheckButton
function app.RestoreIcon(button)
    if not tinted[button] then
        return
    end
    tinted[button] = nil
    local action = button.action
    if action and C_ActionBar.HasAction(action) then
        local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(action)
        if known(isUsable) and known(notEnoughMana) then
            nativeColor(button.icon, isUsable, notEnoughMana)
        end
    end
end
