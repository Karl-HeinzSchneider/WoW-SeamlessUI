-- Run from the repository root: lua src/tests/darkmode.lua
unpack = unpack or table.unpack
local root = arg[1] or "."
local app = {
    running = true,
    addon = {},
    db = {
        profile = {
            enabled = true,
            color = { r = 0.2, g = 0.3, b = 0.4 },
            categories = {
                unitframes = true,
                auras = true,
                bags = true,
            },
        },
    },
    categories = {
        { key = "unitframes", roots = { "PlayerFrame" } },
        { key = "auras", roots = { "BuffFrame" } },
        { key = "bags", roots = { "BankFrame" } },
    },
}
local combat = false
-- Every API except access checks fails on this mock, just as the reported IsObjectType call did.
local function restricted(explicit)
    return setmetatable({
        CanBeAccessedInContext = function()
            return explicit
        end,
        IsForbidden = function()
            return explicit
        end,
    }, {
        __index = function(_, key)
            return function()
                error("Touched restricted object: " .. key)
            end
        end,
    })
end
function InCombatLockdown()
    return combat
end
function hooksecurefunc(owner, method, hook)
    local original = owner[method]
    owner[method] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
local function texture(atlas)
    local t = { color = { 0.8, 0.7, 0.6, 0.5 }, atlas = atlas }
    function t:IsObjectType(kind)
        return kind == "Texture"
    end
    function t:GetVertexColor()
        return unpack(self.color)
    end
    function t:SetVertexColor(r, g, b, a)
        self.color = { r, g, b, a or 1 }
    end
    function t:GetAtlas()
        return self.atlas
    end
    function t:GetTexture()
        return nil
    end
    function t:SetAtlas(a)
        self.atlas = a
    end
    function t:SetAllPoints() end
    function t:SetShown(show)
        self.shown = show
    end
    function t:Hide()
        self.shown = false
    end
    return t
end
local function frame(regions)
    local f = { regions = regions or {}, children = {} }
    function f:GetRegions()
        return unpack(self.regions)
    end
    function f:GetChildren()
        return unpack(self.children)
    end
    function f:IsObjectType()
        return false
    end
    function f:CreateTexture()
        local t = texture()
        self.regions[#self.regions + 1] = t
        return t
    end
    return f
end
local border = texture("UI-HUD-UnitFrame-Player-PortraitOn")
local icon = texture("some-icon")
local glow = texture("some-border-glow")
local absorb = texture("raidframe-absorb-edge")
PlayerFrame = frame({ border, icon, glow, absorb })
PlayerFrame.FrameTexture = border
BuffFrame = frame()
local aura = frame()
aura.Icon = texture()
aura.DebuffBorder = texture("debuff-border")
BuffFrame.children = { aura }
BankFrame = frame()
BankFrame.border = { 0.9, 0.8, 0.7, 0.6 }
function BankFrame:GetBackdrop()
    return {}
end
function BankFrame:GetBackdropBorderColor()
    return unpack(self.border)
end
function BankFrame:SetBackdropBorderColor(...)
    self.border = { ... }
end
assert(loadfile(root .. "/SeamlessDarkmode/src/theme.lua"))("SeamlessDarkmode", app)
local function equal(actual, expected, context)
    for i, v in ipairs(expected) do
        assert(actual[i] == v, context .. " component " .. i .. ": " .. tostring(actual[i]))
    end
end
local forbidden = restricted(true)
local inaccessible = restricted(false)
PlayerFrame.Bg = forbidden
PlayerFrame.TitleBg = inaccessible
PlayerFrame.children = { forbidden, inaccessible }
PlayerFrame.regions[#PlayerFrame.regions + 1] = forbidden
PlayerFrame.regions[#PlayerFrame.regions + 1] = inaccessible
app.addon:Refresh()
equal(border.color, { 0.2, 0.3, 0.4, 0.5 }, "tint and alpha")
equal(icon.color, { 0.8, 0.7, 0.6, 0.5 }, "icon unchanged")
equal(glow.color, { 0.8, 0.7, 0.6, 0.5 }, "glow unchanged")
equal(absorb.color, { 0.8, 0.7, 0.6, 0.5 }, "absorb indicator unchanged")
equal(BankFrame.border, { 0.2, 0.3, 0.4, 0.6 }, "backdrop tint")
assert(aura.regions[1].shown, "aura border created")
border:SetVertexColor(0.1, 0.8, 0.3, 0.4)
equal(border.color, { 0.2, 0.3, 0.4, 0.4 }, "client repaint retained alpha")
app.db.profile.categories.unitframes = false
app.addon:Refresh()
equal(border.color, { 0.1, 0.8, 0.3, 0.4 }, "category restoration")
app.db.profile.enabled = false
app.addon:Refresh()
assert(not aura.regions[1].shown, "aura border removed")
equal(BankFrame.border, { 0.9, 0.8, 0.7, 0.6 }, "backdrop restoration")
app.db.profile = {
    enabled = true,
    color = { r = 0.1, g = 0.1, b = 0.1 },
    categories = {
        unitframes = true,
        auras = true,
        bags = true,
    },
}
combat = true
app.addon:Refresh()
equal(border.color, { 0.1, 0.8, 0.3, 0.4 }, "combat deferred")
combat = false
app.addon:Refresh()
equal(border.color, { 0.1, 0.1, 0.1, 0.4 }, "profile refresh")
local pooled = frame()
pooled.FrameTexture = texture("border")
PlayerFrame.children = { pooled }
app.addon:Refresh()
equal(pooled.FrameTexture.color, { 0.1, 0.1, 0.1, 0.5 }, "new pooled frame")
app.running = false
app:Restore()
assert(not aura.regions[1].shown, "addon disable hides accessible aura border")
app.running = true
app.addon:Refresh()
-- Already tracked objects can become restricted before the next timer/disable.
local function deny(object, methods)
    object.CanBeAccessedInContext = function()
        return false
    end
    for _, method in ipairs(methods) do
        object[method] = function()
            error("Touched newly restricted object: " .. method)
        end
    end
end
deny(pooled.FrameTexture, { "IsObjectType", "GetVertexColor", "SetVertexColor" })
deny(BankFrame, { "GetRegions", "GetBackdrop", "SetBackdropBorderColor" })
deny(aura.regions[1], { "IsObjectType", "SetShown", "Hide", "SetVertexColor" })
app.addon:Refresh()
app.running = false
app:Restore()
equal(border.color, { 0.1, 0.8, 0.3, 0.4 }, "addon disable restores")
-- The newly restricted aura border is deliberately left untouched on disable.
print(
    "PASS: tint, alpha, status exclusions, client repaint, category/master toggles, backdrop restoration, profile change, combat deferral, pooled frames, addon disable, forbidden/restricted objects"
)
