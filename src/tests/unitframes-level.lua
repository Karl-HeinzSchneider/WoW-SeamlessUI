-- Run from the repository root: lua src/tests/unitframes-level.lua
local enabled, combat = true, false
InCombatLockdown = function()
    return combat
end
local function region()
    return {
        alpha = 1,
        scale = 1,
        shown = true,
        SetAlpha = function(self, value)
            self.alpha = value
        end,
        SetScale = function(self, value)
            self.scale = value
        end,
        ClearAllPoints = function(self)
            self.point = nil
        end,
        SetPoint = function(self, point, parent, relativePoint, x, y)
            self.point = { point, parent, relativePoint, x, y }
        end,
    }
end
local function target()
    return {
        TargetFrameContent = {
            TargetFrameContentMain = { LevelText = region(), LevelBackgroundCircle = region() },
            TargetFrameContentContextual = { HighLevelTexture = region() },
        },
    }
end
PlayerLevelText = region()
PlayerFrame = { PlayerFrameContent = { PlayerFrameContentMain = { LevelBackgroundCircle = region() } } }
TargetFrame, FocusFrame = target(), target()
local names = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame" }
local app = {
    addon = {
        NewModule = function(_, _, module)
            module.IsEnabled = function()
                return enabled
            end
            module.RegisterEvent = function() end
            return module
        end,
        IsEnabled = function()
            return enabled
        end,
    },
    unitFrames = {
        Get = function(_, key)
            return { frameName = names[key] }
        end,
    },
    db = {
        profile = {
            unitFrames = {
                player = { levelDisplay = "hidden" },
                target = { levelDisplay = "smaller" },
                focus = { levelDisplay = "default" },
            },
        },
    },
}
assert(loadfile("SeamlessUnitframes/src/level/level.lua"))("SeamlessUnitframes", app)
local module = app.levelDisplay
for _, layout in ipairs({ "current", "legacy" }) do
    app.db.profile.layout = layout
    module:OnEnable()
    assert(PlayerLevelText.alpha == 0)
    assert(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle.alpha == 0)
    local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
    local skull = TargetFrame.TargetFrameContent.TargetFrameContentContextual.HighLevelTexture
    assert(main.LevelText.scale == 0.7 and main.LevelBackgroundCircle.scale == 0.7 and skull.scale == 0.7)
    local circle = main.LevelBackgroundCircle
    assert(circle.point[1] == "CENTER" and circle.point[2] == main and circle.point[3] == "BOTTOMRIGHT")
    assert(math.abs(circle.point[4] * circle.scale + 32.5) < 0.0001)
    assert(math.abs(circle.point[5] * circle.scale - 26.5) < 0.0001)
    assert(FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelText.scale == 1)
    main.LevelText.shown = false -- native skull mode must remain intact
    combat = true
    app.db.profile.unitFrames.target.levelDisplay = "hidden"
    module:Refresh()
    assert(main.LevelText.scale == 0.7)
    combat = false
    module:Refresh()
    assert(main.LevelText.alpha == 0 and main.LevelBackgroundCircle.alpha == 0 and skull.alpha == 0)
    app.db.profile.unitFrames.target = { levelDisplay = "default" }
    module:OnProfileRefresh()
    assert(main.LevelText.alpha == 1 and main.LevelText.scale == 1 and not main.LevelText.shown)
    assert(main.LevelBackgroundCircle.alpha == 1 and skull.alpha == 1 and skull.scale == 1)
    assert(circle.point[1] == "BOTTOMRIGHT" and circle.point[4] == -13 and circle.point[5] == 7)
    enabled = false
    module:OnDisable()
    assert(PlayerLevelText.alpha == 1)
    enabled = true
    app.db.profile.unitFrames.target.levelDisplay = "smaller"
end
for _, key in ipairs({ "player", "focus" }) do
    app.db.profile.unitFrames[key].levelDisplay = "smaller"
end
module:Refresh()
local playerCircle = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle
local focusCircle = FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle
assert(playerCircle.point[3] == "BOTTOMLEFT")
assert(math.abs(playerCircle.point[4] * playerCircle.scale - 32.5) < 0.0001)
assert(math.abs(playerCircle.point[5] * playerCircle.scale - 26.5) < 0.0001)
assert(focusCircle.point[3] == "BOTTOMRIGHT")
assert(math.abs(focusCircle.point[4] * focusCircle.scale + 32.5) < 0.0001)
assert(math.abs(focusCircle.point[5] * focusCircle.scale - 26.5) < 0.0001)
print("unitframes-level: OK")
