-- Cosmetic VIP lifecycle: lua src/tests/preview-unitframes-cosmetics.lua
local editing, combat, enabled = true, false, true
local hooks, callbacks = {}, {}
local character = { name = "VIP", surname = "Preview", class = "MAGE", reaction = 5, displayTexture = "portrait" }
local units = { player = "Live player", target = "Live target", focus = "Live focus" }
local function color(r, g, b)
    return {
        GetRGB = function()
            return r, g, b
        end,
        SetRGB = function() end,
    }
end
CreateColor = color
RAID_CLASS_COLORS = { MAGE = color(0.2, 0.5, 1), WARRIOR = color(1, 0.5, 0.2) }
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
LibStub = function()
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
GetUnitName = function(unit)
    return units[unit]
end
UnitName = GetUnitName
UnitIsPlayer = function(unit)
    return units[unit] ~= nil
end
UnitClass = function()
    return "Warrior", "WARRIOR"
end
GetClassAtlas = function(class)
    return class
end
UnitIsConnected = function()
    return true
end
UnitExists = UnitIsPlayer
UnitFrame_ShouldReplacePortrait = function()
    return false
end
SetPortraitTexture = function(portrait, unit)
    portrait.texture = "live:" .. unit
end
hooksecurefunc = function(owner, name, callback)
    if type(owner) == "string" then
        hooks[owner] = name
    end
end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
local app = {
    addon = {},
    core = {},
    logger = { debug = function() end },
    db = { profile = { unitFrames = {} }, char = { nameOverride = "" } },
    totMover = { movers = {}, Refresh = function() end },
    legacyLayout = {},
}
function app.addon:IsEnabled()
    return enabled
end
function app.addon:NewModule(_, prototype)
    prototype.IsEnabled = function()
        return true
    end
    prototype.RegisterEvent = function() end
    return prototype
end
function app.core:GetPreviewCharacter()
    if editing and not combat then
        return character
    end
end
function app.core:GetEditModeLibrary()
    return {
        RegisterCallback = function(_, name, callback)
            callbacks[name] = callback
        end,
    }
end
function app.legacyLayout:IsWriting()
    return false
end
function app.legacyLayout:HealthAtlas(bar)
    return "Health", bar.texture
end
function app.legacyLayout:HasHealthStatus()
    return true
end
function app.legacyLayout:SetHealthAtlas(texture, atlas)
    texture.atlas = atlas
    return true
end
function app.legacyLayout:CheckRegion(region)
    return region ~= nil
end
function app.legacyLayout:PlayerLoss() end
local frames = {}
for _, key in ipairs({ "player", "target", "focus" }) do
    local frame = {
        unit = key,
        name = {
            SetText = function(self, value)
                self.text = value
            end,
            GetText = function(self)
                return self.text
            end,
        },
        portrait = {},
    }
    function frame.portrait:SetTexture(value)
        self.texture = value
    end
    function frame.portrait:SetAtlas(value)
        self.texture = value
    end
    function frame.portrait:SetTexCoord() end
    local bar = { unit = key, unitFrame = frame, texture = {} }
    function bar.texture:SetAtlas(value)
        self.atlas = value
    end
    function bar:GetStatusBarTexture()
        return self.texture
    end
    function bar:SetStatusBarColor(r, g, b)
        self.rgb = { r, g, b }
    end
    frame.healthbar = bar
    setmetatable(frame, {
        __newindex = function()
            error("Must not write native frame fields")
        end,
    })
    frames[#frames + 1] = frame
    app.db.profile.unitFrames[key] = { nameDisplay = "full", classIcon = false, healthBarColor = "class" }
end
PlayerFrame, TargetFrame, FocusFrame = (unpack or table.unpack)(frames)
app.unitFrames = {
    All = function()
        return frames
    end,
    KeyOf = function(_, frame)
        for _, candidate in ipairs(frames) do
            if candidate == frame then
                return frame.unit
            end
        end
    end,
}
for _, path in ipairs({ "name/namedisplay", "portrait/classicon", "healthcolor/healthcolor", "core/previewcharacters" }) do
    assert(loadfile("SeamlessUnitframes/src/" .. path .. ".lua"))("SeamlessUnitframes", app)
end
app.nameDisplay:OnInitialize()
app.classIcon:OnInitialize()
app.healthColor:OnInitialize()
app.previewCharacters:OnInitialize()
callbacks.enter()
for _, frame in ipairs(frames) do
    assert(frame.name.text == "VIP Preview")
    assert(frame.portrait.texture == "portrait")
    assert(frame.healthbar.rgb[1] == 0.2)
end
-- A native event must repaint the VIP cosmetics while editing.
TargetFrame.name:SetText("Native update")
hooks.UnitFrame_Update(TargetFrame)
assert(TargetFrame.name.text == "VIP Preview")
TargetFrame.portrait.texture = "Native portrait"
hooks.UnitFramePortrait_Update(TargetFrame)
assert(TargetFrame.portrait.texture == "portrait")
TargetFrame.healthbar.rgb = { 0, 1, 0 }
hooks.UnitFrameHealthBar_Update(TargetFrame.healthbar)
assert(TargetFrame.healthbar.rgb[1] == 0.2)
units.target, units.focus = "Different target", nil
editing = false
callbacks.exit()
assert(PlayerFrame.name.text == "Live player")
assert(TargetFrame.name.text == "Different target")
assert(FocusFrame.name.text == nil)
assert(TargetFrame.portrait.texture == "live:target")
assert(TargetFrame.healthbar.rgb[1] == 1)
-- Subsequent native updates use live data again.
FocusFrame.name:SetText("New focus")
hooks.UnitFrame_Update(FocusFrame)
assert(FocusFrame.name.text == "New focus")
editing = true
callbacks.enter()
combat = true
app.previewCharacters:Refresh()
assert(PlayerFrame.name.text == "Live player")
combat = false
callbacks.enter()
enabled = false
app.previewCharacters:OnDisable()
assert(PlayerFrame.name.text == "Live player")
assert(PlayerFrame.healthbar.rgb[1] == 1)
print("Cosmetic VIP lifecycle tests passed")
