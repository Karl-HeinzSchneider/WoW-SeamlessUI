-- Exercise the real feature's event and fallback paths without the game client.
local feature = {}
local secret = {}
local unit, text = "mouseover", "T: First"
local reads, shows, added = 0, 0, 0
local visible, forbidden = true, false
local events = {}
local color = {
    WrapTextInColorCode = function(_, value)
        return value
    end,
}
NORMAL_FONT_COLOR, GRAY_FONT_COLOR = color, color
function CreateColor()
    return color
end
function LibStub()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    }
end
Enum = { TooltipDataType = { Unit = 1 } }
GameTooltip = {
    GetUnit = function()
        return nil, unit
    end,
    IsShown = function()
        return visible
    end,
    IsForbidden = function()
        return forbidden
    end,
    AddLine = function(_, value)
        added = added + 1
        text = value
    end,
    NumLines = function()
        return 2
    end,
    Show = function()
        shows = shows + 1
    end,
}
local rendered
GameTooltipTextLeft2 = {
    SetText = function(_, value)
        rendered = value
    end,
}
function feature:RegisterEvent(event, method)
    events[event] = method
end
function feature:SecureHookScript() end
local app = {
    features = {
        NewFeature = function()
            return feature
        end,
        AnySecret = function(value)
            return value == secret
        end,
    },
}
assert(loadfile("SeamlessTooltip/src/features/targetline.lua"))("SeamlessTooltip", app)
function feature:TargetText()
    reads = reads + 1
    return text
end
feature:OnEnable()
for _, event in ipairs({ "UNIT_TARGET", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }) do
    assert(events[event] == "OnTargetChanged", event)
end
feature:OnUnitTooltip(GameTooltip)
assert(added == 1)
for event, method in pairs(events) do
    text = event
    feature[method](feature, event)
    assert(rendered == event, "Events refresh immediately")
end
local before = reads
feature:OnTooltipUpdate(GameTooltip, 0.49)
assert(reads == before, "Fallback is throttled")
text = "Missed event"
feature:OnTooltipUpdate(GameTooltip, 0.01)
assert(rendered == text, "Fallback catches missing events")
local previousShows = shows
feature:OnTargetChanged()
assert(shows == previousShows, "Unchanged text does not relayout")
text = nil
feature:OnTargetChanged()
assert(rendered == "T: -", "Removed targets clear the line")
feature:OnUnitTooltip(GameTooltip)
text = "New target"
feature:OnTargetChanged()
assert(added == 2, "First target adds a line")
before = reads
unit = secret
feature:OnTargetChanged()
assert(reads == before, "Secret units are ignored")
unit = "target"
feature:OnTargetChanged()
assert(reads == before, "Changed tooltip units wait for the tooltip callback")
unit = "mouseover"
for _, state in ipairs({ "hidden", "forbidden" }) do
    visible, forbidden = state ~= "hidden", state == "forbidden"
    feature:OnTargetChanged()
    assert(reads == before, "Unavailable tooltips are ignored")
end
visible, forbidden = true, false
feature:OnTooltipHide()
feature:OnTargetChanged()
feature:OnTooltipUpdate(GameTooltip, 1)
assert(reads == before, "Hidden tooltip state is cleared")
feature:OnUnitTooltip(GameTooltip)
feature:OnTooltipUpdate(GameTooltip, 0.4)
feature:OnDisable()
feature:OnEnable()
feature:OnUnitTooltip(GameTooltip)
before = reads
feature:OnTooltipUpdate(GameTooltip, 0.1)
assert(reads == before, "New tooltip starts a fresh fallback interval")
print("Tooltip target-line tests passed")
