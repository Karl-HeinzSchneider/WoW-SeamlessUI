-- Native writes throw: previews only read visibility, scale and selection state/bounds.
local editing, combat, enabled, empty = false, false, true, false
local callbacks = {}
local lib = {}
function lib:IsInEditMode()
    return editing
end
function lib:RegisterCallback(event, callback)
    callbacks[event] = callback
end
local function Frame(parent)
    local frame = { parent = parent, shown = true, scripts = {}, strata = "MEDIUM", level = 1 }
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:ClearAllPoints()
        self.point = nil
    end
    function frame:SetSize(width, height)
        self.width, self.height = width, height
    end
    function frame:SetScale(value)
        self.scale = value
    end
    function frame:SetFrameLevel(value)
        if not self.fixedLevel then
            self.level = value
        end
    end
    function frame:SetFrameStrata(value)
        if not self.fixedStrata then
            self.strata = value
        end
    end
    function frame:SetFixedFrameStrata(value)
        self.fixedStrata = value
    end
    function frame:SetFixedFrameLevel(value)
        self.fixedLevel = value
    end
    function frame:EnableMouse(value)
        self.mouse = value
    end
    function frame:SetShown(value)
        self.shown = value
    end
    function frame:IsShown()
        return self.shown
    end
    function frame:SetAllPoints(target)
        self.allPoints = target
    end
    function frame:SetAlpha(alpha)
        self.alpha = alpha
    end
    function frame:SetBlendMode(blend)
        self.blend = blend
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:Show()
        self.shown = true
    end
    function frame:SetText(value)
        self.text = value
    end
    function frame:SetValue(value)
        self.value = value
    end
    function frame:SetMinMaxValues(low, high)
        self.low, self.high = low, high
    end
    function frame:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function frame:CreateTexture()
        return Frame(self)
    end
    frame.CreateMaskTexture, frame.CreateFontString = frame.CreateTexture, frame.CreateTexture
    function frame:GetStatusBarTexture()
        self.fill = self.fill or Frame(self)
        return self.fill
    end
    for _, method in ipairs({
        "SetAtlas",
        "AddMaskTexture",
        "SetStatusBarTexture",
        "SetStatusBarColor",
        "SetColorTexture",
        "SetVertexColor",
        "SetJustifyH",
        "SetWidth",
        "SetHeight",
        "RegisterEvent",
    }) do
        frame[method] = function() end
    end
    return frame
end
CreateFrame = function(_, _, parent)
    return Frame(parent)
end
InCombatLockdown = function()
    return combat
end
GetCVarBool = function()
    return true
end
SetPortraitTexture = function() end
NineSliceUtil = {
    ApplyLayout = function(frame, layout, kit)
        assert(frame.parent, "selection art must belong to an addon-owned frame")
        assert(layout.Center and layout.TopEdge and layout.BottomRightCorner)
        frame.artKit = kit
    end,
}
hooksecurefunc = function(object, method)
    assert(object.Refresh and method == "Refresh", "only owned refresh methods may be hooked")
end
UIParent = {
    GetEffectiveScale = function()
        return 0.8
    end,
}
local names = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", pet = "PetFrame" }
for _, name in pairs(names) do
    local selection = {
        strata = "MEDIUM",
        level = 1000,
        shown = true,
        selected = false,
        hovered = false,
        labelShown = false,
        labelText = name,
        GetFrameStrata = function()
            error("preview must not depend on native selection strata")
        end,
        GetFrameLevel = function()
            error("preview must not depend on native selection levels")
        end,
        IsShown = function(self)
            return self.shown
        end,
        IsSelected = function(self)
            return self.selected
        end,
    }
    selection.MouseOverHighlight = {
        IsShown = function()
            return selection.hovered
        end,
    }
    selection.Label = {
        IsShown = function()
            return selection.labelShown
        end,
        GetText = function()
            return selection.labelText
        end,
    }
    setmetatable(selection, {
        __index = function(_, key)
            error("Forbidden selection access: " .. key)
        end,
        __newindex = function()
            error("Forbidden selection write")
        end,
    })
    _G[name] = setmetatable({
        visible = true,
        scale = 1.2,
        strata = "LOW",
        level = 500,
        GetFrameStrata = function()
            error("preview must not depend on native strata")
        end,
        GetFrameLevel = function()
            error("preview must not depend on native levels")
        end,
        Selection = selection,
        IsShown = function(self)
            return self.visible
        end,
        GetEffectiveScale = function(self)
            return self.scale
        end,
    }, {
        __index = function(_, key)
            error("Forbidden native access: " .. key)
        end,
        __newindex = function()
            error("Forbidden native write")
        end,
    })
end
local app = {
    core = {
        GetEditModeLibrary = function()
            return lib
        end,
    },
    addon = {},
    unitFrames = {},
    db = { profile = { layout = "current", unitFrames = {} } },
    legacyLayout = {
        Refresh = function() end,
        Art = function() end,
        Bar = function() end,
        ApplyToTPreview = function() end,
        ApplyPreviewPower = function() end,
    },
}
function app.addon:NewModule(_, prototype)
    prototype.IsEnabled = function(self)
        return self.enabled ~= false
    end
    return prototype
end
function app.addon:IsEnabled()
    return enabled
end
function app.unitFrames:Get(key)
    return { frameName = names[key] }
end
for key in pairs(names) do
    app.db.profile.unitFrames[key] = {}
end
for _, name in ipairs({ "healthColor", "nameDisplay", "classIcon", "levelDisplay", "portraitDragon" }) do
    app[name] = { Refresh = function() end, ApplyPreview = function() end }
end
app.previewCharacters = {}
function app.previewCharacters:Get(frame, key)
    assert(frame == app.previewOverlays.frames[key])
    if empty then
        return nil
    end
    return { health = 37, healthMax = 100, power = 21, powerMax = 60, reaction = 5, powerType = "MANA", level = 42 }
end
assert(loadfile("SeamlessUnitframes/src/core/previewoverlays.lua"))("SeamlessUnitframes", app)
local module = app.previewOverlays
module:OnInitialize()
module:OnEnable()
for _, frame in pairs(module.frames) do
    assert(not frame.shown)
end
editing = true
callbacks.enter()
for key, frame in pairs(module.frames) do
    assert(frame.shown and frame.parent == UIParent and frame.mouse == false)
    assert(frame.strata == "MEDIUM" and frame.level == 2001)
    assert(frame.SelectionVisual.level > frame.Content.level)
    assert(frame.SelectionVisual.level > frame.HealthBar.level and frame.SelectionVisual.level > frame.ManaBar.level)
    assert(frame.SelectionVisual.allPoints == _G[names[key]].Selection)
    assert(frame.SelectionVisual.artKit == "editmode-actionbar-highlight")
    for _, region in ipairs({
        frame,
        frame.HealthBar,
        frame.ManaBar,
        frame.Content,
        frame.SelectionVisual,
        frame.SelectionVisual.Hover,
    }) do
        assert(region.strata == "MEDIUM" and region.fixedStrata and region.fixedLevel and region.mouse == false)
    end
    assert(math.abs(frame.scale - 1.5) < 0.001)
    assert(frame.point[2] == _G[names[key]])
    assert(frame.HealthBar.value == 37 and frame.HealthBar.high == 100)
    assert(frame.ManaBar.value == 21 and frame.ManaBar.high == 60)
end
-- Actual client combinations no longer affect the preview stack or hide Player.
PlayerFrame.level, PlayerFrame.Selection.strata, PlayerFrame.Selection.level = 1, "LOW", 1000
module:Refresh()
assert(module.frames.player.shown and module.frames.player.level == 2001)
assert(PlayerFrame.level == 1 and PlayerFrame.Selection.strata == "LOW" and PlayerFrame.Selection.level == 1000)
-- Mirror selection, hover and label on the next draw, independent of VIP repaint cadence.
local selection, surface = TargetFrame.Selection, module.frames.target.SelectionVisual
selection.selected, selection.hovered, selection.labelShown, selection.labelText = true, true, true, "Target"
module.driver.scripts.OnUpdate(nil, 0.01)
assert(surface.artKit == "editmode-actionbar-selected")
assert(surface.Hover.shown and surface.Hover.blend == "ADD" and surface.Hover.alpha == 0.4)
assert(surface.Label.shown and surface.Label.text == "Target")
selection.selected, selection.hovered, selection.labelShown = false, false, false
module.driver.scripts.OnUpdate(nil, 0.01)
assert(surface.artKit == "editmode-actionbar-highlight" and not surface.Hover.shown and not surface.Label.shown)
-- Turning off a native Frames checkbox hides the owned preview, without changing the live frame.
selection.shown = false
module.driver.scripts.OnUpdate(nil, 0.01)
assert(not module.frames.target.shown and TargetFrame.visible)
selection.shown = true
module:Refresh()
assert(module.frames.target.shown)
TargetFrame.visible = false
module.driver.scripts.OnUpdate(nil, 0.2)
assert(not module.frames.target.shown and module.frames.player.shown)
app.db.profile.layout = "legacy"
module:OnProfileRefresh()
assert(module.frames.player.HealthBar.height == 19)
combat = true
module.driver.scripts.OnEvent()
for _, frame in pairs(module.frames) do
    assert(not frame.shown)
end
combat = false
module.driver.scripts.OnEvent()
assert(module.frames.player.shown)
enabled = false
module:OnDisable()
assert(not module.frames.player.shown)
enabled = true
empty = true
module:Refresh()
assert(not module.frames.player.shown)
empty = false
editing = false
callbacks.exit()
assert(not module.driver.shown)
for _, frame in pairs(module.frames) do
    assert(not frame.shown)
end
print("Owned VIP/selection composition, input isolation and lifecycle tests passed")
