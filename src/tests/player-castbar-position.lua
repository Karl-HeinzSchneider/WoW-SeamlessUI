-- lua src/tests/player-castbar-position.lua
GetLocale = function()
    return "enUS"
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")
CopyTable = function(value)
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = item
    end
    return copy
end
UIParent = {}
Enum = { EditModeSystem = { CastBar = 4 }, EditModeCastBarSetting = { ShowCastTime = 2 } }
local shared = {
    systems = {
        {
            system = 4,
            settings = { { setting = 2, value = 1 } },
            anchorInfo = {
                point = "BOTTOM",
                relativePoint = "BOTTOM",
                relativeTo = "UIParent",
                offsetX = 30,
                offsetY = 180,
            },
        },
    },
}
EditModeManagerFrame = {
    GetActiveLayoutInfo = function()
        return shared
    end,
}
-- Any access to another bar or the player unit frame fails.
PlayerCastingBarFrame = setmetatable({}, {
    __index = function()
        error("read native bar")
    end,
})
PlayerFrame = setmetatable({}, {
    __index = function()
        error("read player unit frame")
    end,
})
local layout, editMode = "Modern", false
local callbacks, moved, spec = {}, nil, nil
local lib = {
    GetActiveLayoutName = function()
        return layout
    end,
    IsInEditMode = function()
        return editMode
    end,
    AddFrame = function(_, _, callback)
        moved = callback
    end,
    AddFrameSettings = function() end,
    RefreshFrameSettings = function() end,
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
}
local function frame()
    local value = {}
    for _, method in ipairs({
        "Hide",
        "SetClampedToScreen",
        "SetLook",
        "SetSize",
        "SetScale",
        "SetMinMaxValues",
        "SetValue",
        "ClearAllPoints",
    }) do
        value[method] = function() end
    end
    function value:SetPoint(point, parent, relativePoint, x, y)
        assert(parent == UIParent)
        self.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
    function value:SetShown(shown)
        self.shown = shown
    end
    function value:UpdateShownState(shown)
        self.shown = shown
    end
    function value:ShouldShowCastBar()
        return true
    end
    for _, name in ipairs({ "Text", "CastTimeText", "Icon" }) do
        value[name] = {
            SetText = function() end,
            SetShown = function() end,
            SetTexture = function() end,
            SetSize = function() end,
            ClearAllPoints = function() end,
            SetPoint = function() end,
        }
    end
    return value
end
CreateFrame = function()
    return frame()
end
local real = frame()
local app = {
    db = {
        profile = {
            positions = { player = {} },
            player = {
                scale = 1.5,
                width = 208,
                height = 11,
                iconSize = 16,
                icon = { enabled = true },
                castTime = { format = "REMAINING", decimals = 1 },
            },
        },
    },
    addon = {
        IsEnabled = function()
            return true
        end,
    },
    GetPlayerBar = function()
        return real
    end,
    FormatCastTime = function()
        return "5"
    end,
    core = {
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshOptions = function() end,
        GetPositionOptions = function(_, value)
            spec = value
            return { args = {} }, { args = {} }
        end,
        GetEditModePageSettings = function()
            return {}
        end,
        RegisterEditModeOptions = function() end,
    },
}
assert(loadfile("SeamlessCastbar/src/playerposition.lua"))("SeamlessCastbar", app)
app.InitializePlayerSettings()
assert(app.db.profile.player.showCastTime)
shared.systems[1].settings[1].value = 0
app.InitializePlayerSettings()
assert(app.db.profile.player.showCastTime, "visibility is imported once, then independent")
app.ApplyPlayerPosition()
assert(real.position.x == 20 and real.position.y == 120, "saved screen offsets import at the user's scale")
shared.systems[1].anchorInfo.offsetY = 999
app.ApplyPlayerPosition()
assert(real.position.y == 120, "native layout edits do not move an imported position")
local options = app.PlayerCastbarPosition()
assert(options.layoutStored and #spec.anchorFrames == 1 and spec.anchorFrames[1].value == "UIParent")
app.RegisterPlayerEditMode()
editMode = true
callbacks.enter()
assert(app.GetPlayerPreview().shown and not real.shown)
moved(nil, nil, "TOPRIGHT", -50, -70)
assert(real.position.point == "TOPRIGHT" and real.position.x == -50)
spec.set("relativeTo", "PlayerFrame")
assert(app.GetPlayerPosition().relativeTo == "UIParent")
layout = "Classic"
shared = { systems = {} }
callbacks.layout()
assert(real.position.point == "CENTER" and real.position.x == 0)
layout = "Modern"
callbacks.layout()
assert(real.position.x == -50 and real.position.y == -70)
spec.reset()
assert(spec.isDefault() and real.position.point == "CENTER")
print("PASS: UIParent-only player placement, independent migration, dragging, layout changes and reset")
