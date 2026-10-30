unpack = unpack or table.unpack
local rotateMinimap = false
function GetCVarBool(key)
    assert(key == "rotateMinimap")
    return rotateMinimap
end
function SetCVar(key, value)
    assert(key == "rotateMinimap" and (value == "1" or value == "0"))
    rotateMinimap = value == "1"
    MinimapCluster:UpdateMinimapConfig()
end
CVarCallbackRegistry = {
    GetCVarValueBool = function(_, key)
        assert(key == "rotateMinimap")
        return rotateMinimap
    end,
}
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
local buttonRefreshes = {}
local icons = {
    GetButtonList = function()
        return { "Seamless", "OtherAddon" }
    end,
    Refresh = function(_, name)
        buttonRefreshes[#buttonRefreshes + 1] =
            { name = name, shape = GetMinimapShape and GetMinimapShape() or "ROUND" }
    end,
}
function LibStub(name)
    if name == "LibDBIcon-1.0" then
        return icons
    end
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
Enum = { EditModeSystem = { Minimap = 42 }, EditModeMinimapSetting = { RotateMinimap = 2 } }
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
app.core.RefreshOptions = function(_, name)
    assert(name == "SeamlessUI")
end
app.core.GetCVarOptionInfo = function(_, name)
    assert(name == "rotateMinimap")
    return false, true, true
end
local nativeRotation = 0
local editable = true
app.core.GetFramePositionService = function()
    return {
        ReadSetting = function(_, frame, setting)
            assert(frame == MinimapCluster and setting == 2)
            return nativeRotation
        end,
        ApplySetting = function(_, frame, setting, value)
            assert(frame == MinimapCluster and setting == 2)
            nativeRotation = value
            SetCVar("rotateMinimap", tostring(value))
            return true
        end,
        CanEdit = function()
            return editable
        end,
        GetDefaultSetting = function()
            return 0
        end,
    }
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
assert(registration.options[1].key == "square" and registration.options[2].key == "rotateMinimap")
assert(registration.options[2].blizzard, "rotation wrapper carries Blizzard metadata into Edit Mode")
local row = registration.options[3]
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
Enum.EditModeMinimapSetting.HeaderUnderneath = 1
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
assert(#registration.options == 9, "all Style settings reach Edit Mode")
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
function map:SetSize(width, height)
    error("Square styling must never resize the minimap")
end
function map:SetWidth()
    error("Square styling must never resize the minimap")
end
function map:SetHeight()
    error("Square styling must never resize the minimap")
end
function map:SetScale()
    error("Square styling must never rescale the minimap")
end
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
border.texCoords = { 0, 1, 0, 1 }
function border:GetTexCoord()
    return unpack(self.texCoords)
end
function border:SetTexCoord(...)
    self.texCoords = { ... }
end
function border:SetTexture(texture)
    self.texture = texture
end
function border:ClearAllPoints()
    self.point = nil
end
function border:GetNumPoints()
    return self.point and 1 or 0
end
function border:GetPoint()
    return unpack(self.point)
end
function border:SetPoint(...)
    self.point = { ... }
end
function border:SetSize(width, height)
    self.width, self.height = width, height
end
border.point = { "CENTER", map, "CENTER", 0, 0 }
MinimapCompassTexture, MinimapCompassTextureUnderlay = border, newFrame()
function cluster:UpdateMinimapConfig()
    map:SetMaskTexture("native-mask")
    MinimapCompassTexture:SetTexture("native-border")
    MinimapCompassTexture:Show()
    MinimapCompassTextureUnderlay:Show()
end
module:OnEnable()
rows.square.set(true)
assert(map.mask == "Interface\\Buttons\\WHITE8X8" and border:IsShown())
assert(MinimapCompassTexture:IsShown() and not MinimapCompassTextureUnderlay:IsShown())
assert(module.squareBorder == MinimapCompassTexture, "border uses engine-rotated compass layer")
assert(math.abs(border.width * 406 / 512 - 198) < 0.001, "opening fits map width")
assert(math.abs(border.height * 394 / 512 - 198) < 0.001, "opening fits map height")
assert(border.point[4] == 0 and border.point[5] == 0, "compass pivots at map center")
assert(map.width == 198 and map.height == 198, "square style preserves native dimensions")
assert(math.abs((border.texCoords[1] + border.texCoords[2]) / 2 - 255.5 / 512) < 0.001)
assert(math.abs((border.texCoords[3] + border.texCoords[4]) / 2 - 261.5 / 512) < 0.001)
cluster:UpdateMinimapConfig()
assert(map.mask == "Interface\\Buttons\\WHITE8X8", "native rotation cannot reset square mask")
assert(map.width == 198 and map.height == 198, "native refresh preserves dimensions")
assert(border.texture:find("minimap_square_arrow", 1, true), "native updates retain custom compass art")
app.db.profile = { minimap = {} }
module:OnProfileRefresh()
assert(map.mask == "native-mask" and border.texture == "native-border", "profile restores native shape")
rows.square.set(true)
module:OnDisable()
assert(map.mask == "native-mask" and border.texture == "native-border" and border.point[5] == 0)
assert(map.width == 198 and map.height == 198, "disable restores native dimensions")
assert(border.texCoords[1] == 0 and border.texCoords[2] == 1, "disable restores native UVs")
print("Minimap square mask, border alignment, rotation and restoration OK")

-- Button addons query the public shape API; it must follow the current profile.
local previousShape = function()
    return "CUSTOM"
end
GetMinimapShape = previousShape
module:OnEnable()
assert(GetMinimapShape() == "SQUARE")
rows.square.set(false)
assert(GetMinimapShape() == "ROUND")
app.db.profile = { minimap = { square = true } }
assert(GetMinimapShape() == "SQUARE", "shape resolves current profile without caching")
module:OnProfileRefresh()
local refreshCount = #buttonRefreshes
rows.rotateMinimap.set(true)
assert(rows.rotateMinimap.get() and nativeRotation == 1, "rotation writes the native layout setting")
editable = false
assert(rows.rotateMinimap.disabled(), "rotation respects native layout editability")
editable = true
assert(app.db.profile.minimap.rotateMinimap == nil, "rotation is not stored in the addon profile")
assert(#buttonRefreshes == refreshCount + 2, "rotation repositions every registered button")
assert(buttonRefreshes[#buttonRefreshes].shape == "ROUND", "buttons refresh after shape provider changes")
module:Apply()
assert(#buttonRefreshes == refreshCount + 2, "unchanged shape avoids repeated button refreshes")
assert(GetMinimapShape() == "ROUND", "button geometry matches rotation fallback")
assert(map.mask == "native-mask" and border.texture == "native-border", "rotation uses native rendering")
assert(app.db.profile.minimap.square, "rotation preserves square preference")
assert(map.width == 198 and map.height == 198, "rotation fallback preserves native dimensions")
rows.rotateMinimap.set(false)
assert(not rows.rotateMinimap.get())
assert(#buttonRefreshes == refreshCount + 4, "turning rotation off repositions every button")
assert(buttonRefreshes[#buttonRefreshes].shape == "SQUARE")
assert(GetMinimapShape() == "SQUARE", "square geometry returns when rotation stops")
assert(map.mask == "Interface\\Buttons\\WHITE8X8", "square mask returns when rotation stops")
module:OnDisable()
assert(GetMinimapShape == previousShape, "disable restores previous shape provider")
GetMinimapShape = nil
module:OnEnable()
module:OnDisable()
assert(GetMinimapShape == nil, "disable restores an absent provider")
module:OnEnable()
GetMinimapShape = previousShape
module:OnDisable()
assert(GetMinimapShape == previousShape, "disable preserves another addon's replacement")
print("Minimap public shape API, profile changes and provider restoration OK")
