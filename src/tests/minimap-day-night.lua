-- Run from the repository root: lua src/tests/minimap-day-night.lua
local module = { hooks = {}, functionHooks = {} }
function module:IsEnabled()
    return true
end
function module:IsHooked(frame, method)
    if method == "OnShow" then
        return self.hooks[frame] ~= nil
    end
    return self.functionHooks[frame] and self.functionHooks[frame][method] ~= nil
end
function module:SecureHook(object, method, handler)
    self.functionHooks[object] = self.functionHooks[object] or {}
    local original = object[method]
    self.functionHooks[object][method] = original
    object[method] = function(...)
        original(...)
        self[handler](self)
    end
end
function module:SecureHookScript(frame, _, method)
    self.hooks[frame] = method
end
function module:RegisterEvent() end
function module:UnregisterAllEvents() end
function module:UnhookAll()
    self.hooks = {}
    for object, methods in pairs(self.functionHooks) do
        for method, original in pairs(methods) do
            object[method] = original
        end
    end
    self.functionHooks = {}
end
function IsLoggedIn()
    return true
end
local app = {
    core = { RefreshEditModeSystemOptions = function() end },
    addon = {
        NewModule = function()
            return module
        end,
    },
    db = { profile = { hideMinimapDayNight = false, minimap = {} } },
}
assert(loadfile("SeamlessUI/src/features/minimap.lua"))("SeamlessUI", app)
-- Load the real page and verify Edit Mode uses its Style control and callbacks.
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
Enum = { EditModeSystem = { Minimap = 42 } }
app.optionPages = {}
app.core.GetEditModeButtonSection = function()
    return {}
end
app.core.GetEditModePositionButton = function()
    return {}
end
app.core.GetNativePositionOptions = function()
    return {}
end
app.addon.IsEnabled = function()
    return true
end
local registration
function app.core:RegisterEditModeSystemOptions(_, spec)
    registration = spec
end
assert(loadfile("SeamlessUI/src/options/minimap.lua"))("SeamlessUI", app)
module:OnInitialize()
assert(registration.system == Enum.EditModeSystem.Minimap and registration.name == "Style")
assert(registration.enabled())
local row = registration.options[1]
assert(row.get == app.optionPages.minimap.config.args.style.args.hideMinimapDayNight.get)
assert(row.default == false and row.type == "toggle")
module:OnEnable() -- Also safe before Blizzard_Minimap loads.
local frame = { shown = true }
function frame:IsShown()
    return self.shown
end
function frame:Hide()
    self.shown = false
end
function frame:Show()
    self.shown = true
    if module.hooks[self] then
        module[module.hooks[self]](module)
    end
end
MinimapCluster = { DielFrame = frame }
module:Apply()
assert(frame.shown, "visible by default")
row.set(true)
assert(row.get(), "Edit Mode writes the shared profile preference")
assert(not frame.shown, "toggle hides the indicator")
frame:Show()
assert(not frame.shown, "native Show cannot undo the preference")
app.db.profile = { hideMinimapDayNight = false, minimap = {} }
module:OnProfileRefresh()
assert(frame.shown, "profile change restores the indicator")
app.db.profile.hideMinimapDayNight = true
module:OnProfileRefresh()
module:OnDisable()
assert(frame.shown, "addon disable restores the indicator")
module:OnEnable()
assert(not frame.shown, "re-enable reapplies the preference")
print("Minimap day/night visibility OK")

local function newFrame()
    return setmetatable({ shown = true }, { __index = frame })
end
local cluster = MinimapCluster
AddonCompartmentFrame, GameTimeFrame = newFrame(), newFrame()
TimeManagerClockButton = newFrame()
cluster.Tracking, cluster.ZoneTextButton, cluster.IndicatorFrame = newFrame(), newFrame(), newFrame()
local container = { width = 215, height = 226, scale = 1 }
cluster.MinimapContainer = container
function container:GetWidth()
    return self.width
end
function container:GetHeight()
    return self.height
end
function container:GetScale()
    return self.scale
end
function container:ClearAllPoints()
    self.point = nil
end
function container:SetPoint(...)
    self.point = { ... }
end
function cluster:GetFixedSize()
    return self.fixedWidth, self.fixedHeight
end
function cluster:SetFixedSize(width, height)
    self.fixedWidth, self.fixedHeight = width, height
end
function cluster:GetWidthPadding()
    return 20
end
function cluster:GetHeightPadding()
    return 0
end
function cluster:Layout()
    self.width = self.fixedWidth or (container.width * container.scale + 20)
    self.height = self.fixedHeight or (container.height * container.scale + 30)
end
function cluster:GetSettingValueBool()
    return self.headerUnderneath
end
function cluster:SetHeaderUnderneath(value)
    self.headerUnderneath = value
    container:SetPoint(value and "BOTTOM" or "TOP", self, value and "BOTTOM" or "TOP", 10, value and 30 or -30)
end
function cluster:SetEditModeScale(scale)
    container.scale = scale
    self:SetHeaderUnderneath(self.headerUnderneath)
    self:Layout()
end
function cluster:UpdateMinimapConfig()
    container.width, container.height = 240, 240
end
Enum.EditModeMinimapSetting = { HeaderUnderneath = 1 }
local controls = {
    { "hideAddonCompartment", AddonCompartmentFrame },
    { "hideTracking", cluster.Tracking },
    { "hideCalendar", GameTimeFrame },
    { "hideClock", TimeManagerClockButton },
    { "hideZoneText", cluster.ZoneTextButton },
}
local rows = {}
for _, option in ipairs(registration.options) do
    rows[option.key] = option
end
assert(#registration.options == 8, "all Style settings reach Edit Mode")
-- Exhaust every combination of individual switches, independently of the header switch.
for combination = 0, 31 do
    for index, control in ipairs(controls) do
        rows[control[1]].set(math.floor(combination / 2 ^ (index - 1)) % 2 == 1)
    end
    for _, control in ipairs(controls) do
        assert(control[2]:IsShown() == not rows[control[1]].get(), "independent button visibility")
    end
    rows.hideHeader.set(true)
    for _, control in ipairs(controls) do
        assert(not control[2]:IsShown(), "header overrides individual choices")
    end
    assert(not cluster.IndicatorFrame:IsShown())
    assert(cluster.height == container.height * container.scale, "header space removed")
    GameTimeFrame:Show()
    assert(not GameTimeFrame:IsShown(), "native Show respects header override")
    TimeManagerClockButton:Show()
    assert(not TimeManagerClockButton:IsShown(), "header override also hides the clock")
    rows.hideHeader.set(false)
    for _, control in ipairs(controls) do
        assert(control[2]:IsShown() == not rows[control[1]].get(), "header restores individual choices")
    end
    assert(cluster.IndicatorFrame:IsShown() and cluster.fixedHeight == nil)
end
for _, underneath in ipairs({ false, true }) do
    cluster:SetHeaderUnderneath(underneath)
    rows.hideHeader.set(true)
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        cluster:SetEditModeScale(scale)
        assert(cluster.height == container.height * scale, "compact bounds follow native scale")
        assert(container.point[1] == "TOP" and container.point[5] == 0, "no header anchor gap")
    end
    cluster:UpdateMinimapConfig()
    assert(cluster.width == 240 * container.scale + 20, "bounds follow rotation geometry")
    rows.hideHeader.set(false)
    assert(container.point[1] == (underneath and "BOTTOM" or "TOP"), "native header placement restored")
end
rows.hideHeader.set(true)
app.db.profile = { hideMinimapDayNight = false, minimap = {} }
module:OnProfileRefresh()
assert(cluster.fixedHeight == nil and GameTimeFrame:IsShown(), "profile restores native header")
rows.hideHeader.set(true)
module:OnDisable()
assert(cluster.fixedHeight == nil and cluster.ZoneTextButton:IsShown(), "disable restores layout and visibility")
print("Minimap visibility combinations, Edit Mode rows, header bounds, scale and restoration OK")

local map = { width = 198, height = 198 }
container.Minimap = map
function map:GetWidth()
    return self.width
end
function map:GetHeight()
    return self.height
end
function map:SetMaskTexture(mask)
    self.mask = mask
end
local border = newFrame()
function border:SetTexture(texture)
    self.texture = texture
end
function border:ClearAllPoints() end
function border:SetPoint(...)
    self.point = { ... }
end
function border:SetSize(width, height)
    self.width, self.height = width, height
end
MinimapBackdrop = {
    CreateTexture = function()
        return border
    end,
}
MinimapCompassTexture, MinimapCompassTextureUnderlay = newFrame(), newFrame()
function cluster:UpdateMinimapConfig()
    map:SetMaskTexture("native-mask")
    MinimapCompassTexture:Show()
    MinimapCompassTextureUnderlay:Show()
end
module:OnEnable()
rows.square.set(true)
assert(map.mask == "Interface\\Buttons\\WHITE8X8" and border:IsShown())
assert(not MinimapCompassTexture:IsShown() and not MinimapCompassTextureUnderlay:IsShown())
assert(math.abs(border.width * 376 / 512 - 198) < 0.001, "opening fits map width")
assert(math.abs(border.height * 364 / 512 - 198) < 0.001, "opening fits map height")
cluster:UpdateMinimapConfig()
assert(map.mask == "Interface\\Buttons\\WHITE8X8", "native rotation cannot reset square mask")
assert(not MinimapCompassTexture:IsShown(), "native rotation cannot restore round border")
app.db.profile = { minimap = {} }
module:OnProfileRefresh()
assert(map.mask == "native-mask" and not border:IsShown(), "profile restores native shape")
rows.square.set(true)
module:OnDisable()
assert(map.mask == "native-mask" and MinimapCompassTexture:IsShown() and not border:IsShown())
print("Minimap square mask, border alignment, rotation and restoration OK")
