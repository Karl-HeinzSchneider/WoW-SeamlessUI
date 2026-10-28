-- Native writes throw: VIP overlays must only read visibility/scale and anchor their own frames.
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
    local frame = { parent = parent, shown = true, scripts = {} }
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
        self.level = value
    end
    function frame:SetFrameStrata(value)
        self.strata = value
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
        "SetAllPoints",
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
    _G[name] = setmetatable({
        visible = true,
        scale = 1.2,
        strata = "LOW",
        level = 500,
        GetFrameStrata = function(self)
            return self.strata
        end,
        GetFrameLevel = function(self)
            return self.level
        end,
        Selection = setmetatable({
            strata = "MEDIUM",
            level = 20,
            GetFrameStrata = function(self)
                return self.strata
            end,
            GetFrameLevel = function(self)
                return self.level
            end,
        }, {
            __index = function(_, key)
                error("Forbidden selection access: " .. key)
            end,
            __newindex = function()
                error("Forbidden selection write")
            end,
        }),
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
    assert(frame.strata == "LOW" and frame.level == 520)
    assert(frame.HealthBar.level == 521 and frame.ManaBar.level == 521 and frame.Content.level == 522)
    for _, region in ipairs({ frame, frame.HealthBar, frame.ManaBar, frame.Content }) do
        assert(region.strata == "LOW" and region.fixedStrata and region.fixedLevel)
    end
    assert(math.abs(frame.scale - 1.5) < 0.001)
    assert(frame.point[2] == _G[names[key]])
    assert(frame.HealthBar.value == 37 and frame.HealthBar.high == 100)
    assert(frame.ManaBar.value == 21 and frame.ManaBar.high == 60)
end
-- Even a lower selection level must draw over ALL preview layers by strata.
PlayerFrame.Selection.level = 1
module.driver.scripts.OnUpdate(nil, 0.2)
assert(module.frames.player.strata == "LOW" and module.frames.player.level == 520)
assert(module.frames.player.HealthBar.strata == "LOW" and module.frames.player.ManaBar.strata == "LOW")
assert(module.frames.player.Content.strata == "LOW")
assert(PlayerFrame.Selection.strata == "MEDIUM" and PlayerFrame.Selection.level == 1)
PlayerFrame.Selection.strata = "LOW"
module:Refresh()
assert(not module.frames.player.shown, "never put preview artwork into the selection stratum")
PlayerFrame.Selection.strata = "MEDIUM"
PlayerFrame.level = 25
module:Refresh()
assert(module.frames.player.shown and module.frames.player.level == 45 and module.frames.player.Content.level == 47)
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
print("VIP overlay lifecycle, layering and native isolation tests passed")
