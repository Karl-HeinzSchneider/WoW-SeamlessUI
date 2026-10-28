-- Run from the repository root: lua src/tests/unitframes-dragon.lua
local combat, enabled, moduleEnabled = false, true, true
local texture = {}
function texture:SetTexture(value)
    self.path = value
end
function texture:SetAtlas(value)
    self.atlas = value
end
function texture:SetSize(w, h)
    self.width, self.height = w, h
end
function texture:SetTexCoord(...)
    self.uv = { ... }
end
function texture:ClearAllPoints() end
function texture:SetPoint(...)
    self.point = { ... }
end
function texture:Show()
    self.shown = true
end
function texture:Hide()
    self.shown = false
end
local created = 0
PlayerFrame = {
    portrait = {},
    PlayerFrameContainer = {
        CreateTexture = function()
            created = created + 1
            return texture
        end,
    },
}
InCombatLockdown = function()
    return combat
end
C_Texture = {
    GetAtlasInfo = function()
        return { leftTexCoord = 0.1, rightTexCoord = 0.4, topTexCoord = 0.2, bottomTexCoord = 0.8 }
    end,
}
local hook
hooksecurefunc = function(_, _, callback)
    hook = callback
end
local app = {
    db = { profile = { layout = "current", unitFrames = { player = { portraitDragon = "none" } } } },
    addon = {
        IsEnabled = function()
            return enabled
        end,
        NewModule = function(_, _, module)
            module.IsEnabled = function()
                return moduleEnabled
            end
            module.RegisterEvent = function() end
            return module
        end,
    },
    legacyLayout = {
        CheckPaths = function()
            return true
        end,
    },
    legacyAtlases = {},
}
assert(loadfile("SeamlessUnitframes/src/layout/atlas.lua"))("SeamlessUnitframes", app)
assert(loadfile("SeamlessUnitframes/src/portrait/dragon.lua"))("SeamlessUnitframes", app)
local module = app.portraitDragon
module:OnEnable()
assert(created == 0, "None creates no decoration")
for _, style in ipairs({ "elite", "rare", "boss" }) do
    app.db.profile.unitFrames.player.portraitDragon = style
    module:Refresh()
    assert(texture.shown and texture.uv[1] == 0.4 and texture.uv[2] == 0.1, "native art is mirrored")
end
assert(created == 1, "reuse our texture")
combat = true
app.db.profile.layout = "legacy"
module:Refresh()
assert(texture.path == nil, "defer layout changes in combat")
combat = false
hook()
assert(texture.path == "Interface/HUD/UIUnitFrameBoss2x", "legacy art sheet")
assert(texture.width == 99 and texture.uv[1] > texture.uv[2], "legacy size and mirroring")
app.db.profile = { layout = "current", unitFrames = { player = { portraitDragon = "none" } } }
module:OnProfileRefresh()
assert(not texture.shown, "new profile resolves at use time")
app.db.profile.unitFrames.player.portraitDragon = "elite"
module:Refresh()
combat, enabled, moduleEnabled = true, false, false
module:OnDisable()
assert(not texture.shown, "disable hides existing decoration during combat")
print("PASS: portrait dragon styles, mirroring, layout, profiles, combat and disable")
