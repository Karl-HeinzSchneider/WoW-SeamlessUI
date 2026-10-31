---@type string, SeamlessCastbar
local _, app = ...

-- How long a bar stays after a cast. Both cast bar templates fade out through two animation
-- groups: `FadeOutAnim` after a finished cast (0.2 s delay, then a 0.3 s fade) and
-- `HoldFadeOutAnim` after an interrupt or failure (1 s hold, then the same fade). We change the
-- delay and the hold and put the client's values back when the option is switched off.

---@param bar StatusBar
---@return Animation?, Animation?
local function animations(bar)
    local fade = bar.FadeOutAnim and bar.FadeOutAnim:GetAnimations()
    local hold = bar.HoldFadeOutAnim and bar.HoldFadeOutAnim:GetAnimations()
    return fade, hold
end

---@type table<StatusBar, { success: number, interrupt: number }>
local originals = {}

---@param bar StatusBar
function app.RestoreHold(bar)
    local original = originals[bar]
    if not original then
        return
    end
    originals[bar] = nil
    local fade, hold = animations(bar)
    if fade then
        fade:SetStartDelay(original.success)
    end
    if hold then
        hold:SetDuration(original.interrupt)
    end
end

---@param bar StatusBar
function app.ApplyHold(bar)
    local settings = app.Settings(bar) and app.Settings(bar).hold
    if not (settings and settings.enabled) then
        app.RestoreHold(bar)
        return
    end
    local fade, hold = animations(bar)
    if not fade or not hold then
        return
    end
    if not originals[bar] then
        originals[bar] = { success = fade:GetStartDelay(), interrupt = hold:GetDuration() }
    end
    fade:SetStartDelay(settings.success)
    hold:SetDuration(settings.interrupt)
end
