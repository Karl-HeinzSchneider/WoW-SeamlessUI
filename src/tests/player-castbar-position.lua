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
Enum = {
    EditModeSystem = { CastBar = 4 },
    EditModeCastBarSetting = { ShowCastTime = 2 },
    GameRule = { CustomActionbarOverlayHeightOffset = 1 },
}
local actionHeight = 100
EditModeUtil = {
    GetBottomActionBarHeight = function()
        return actionHeight
    end,
}
C_GameRules = {
    GetGameRuleAsFloat = function()
        return 0
    end,
}
BOTTOM_FRAME_CONTAINER_MARGIN, MAIN_ACTION_BAR_OFFSET_Y = 15, -4
local lower = {
    layoutIndex = 3,
    GetScale = function()
        return 2
    end,
}
GetBottomManagedFrameContainer = function()
    return {
        respectChildScale = true,
        spacing = 10,
        GetPadding = function()
            return 0, 0, 0, 0
        end,
        GetLayoutChildren = function()
            return { lower }
        end,
        GetChildSize = function()
            return 100, 12
        end,
        GetChildPadding = function()
            return 0, 0, 1, 2
        end,
    }
end
local shared = {
    systems = {
        {
            system = 4,
            isInDefaultPosition = false,
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
assert(real.position.point == "BOTTOM" and real.position.x == 0)
assert(real.position.y == (100 + 15 + 8 + 24 + 1 + 2 + 10) / 1.5)
actionHeight = 500
app.ApplyPlayerPosition()
assert(real.position.y == 160 / 1.5, "default snapshots shared layout without following other frames")
layout = "Modern"
callbacks.layout()
assert(real.position.x == -50 and real.position.y == -70)
spec.reset()
assert(spec.isDefault() and real.position.point == "BOTTOM")
app.db.profile.player.scale = 2
app.ApplyPlayerPosition()
assert(real.position.y == 160 / 2, "default screen location remains stable across scale changes")
layout = "No action bars"
actionHeight = 0
callbacks.layout()
assert(real.position.y == (-4 + 8 + 24 + 1 + 2 + 10) / 2)
print("PASS: UIParent-only player placement, independent migration, dragging, layout changes and reset")
layout = "Previously default"
shared = { systems = { { system = 4, isInDefaultPosition = true } } }
app.db.profile.positions.player[layout] =
    { point = "CENTER", relativePoint = "CENTER", relativeTo = "UIParent", x = 0, y = 0 }
callbacks.layout()
assert(real.position.point == "CENTER", "existing saved positions are preserved")
spec.reset()
assert(real.position.point == "BOTTOM", "Reset Position switches an existing layout to the native default")
shared.systems[1].isInDefaultPosition = false
app.db.profile.positions.player[layout] =
    { point = "CENTER", relativePoint = "CENTER", relativeTo = "UIParent", x = 0, y = 0 }
callbacks.layout()
assert(real.position.point == "CENTER", "an explicitly moved center position is preserved")

actionHeight = 200
app.RefreshPlayerDefault()
assert(real.position.point == "CENTER", "deferred default initialization must not move a saved bar")
spec.reset()
assert(real.position.y == (200 + 15 + 8 + 24 + 1 + 2 + 10) / 2)
