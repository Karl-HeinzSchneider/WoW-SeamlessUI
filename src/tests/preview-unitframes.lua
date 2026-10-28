-- Custom preview isolation: lua src/tests/preview-unitframes.lua
local enabled, editing, combat = true, true, false
local event
local refreshes, requests = 0, 0
local target, focus, native = {}, {}, {}
local app = { addon = {}, core = {}, totMover = { movers = { targettarget = target, focustarget = focus } } }
local overlays = { player = {}, target = {}, focus = {}, pet = {} }
app.previewOverlays = { frames = overlays, Refresh = function() end }
function app.addon:IsEnabled()
    return enabled
end
function app.addon:NewModule(_, prototype)
    return setmetatable({
        enabled = true,
        IsEnabled = function(self)
            return self.enabled
        end,
    }, { __index = prototype })
end
function app.core:GetPreviewCharacter(id)
    requests = requests + 1
    if not editing or combat then
        return nil
    end
    return { name = id }
end
function app.totMover:Refresh()
    refreshes = refreshes + 1
end
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, callback)
            event = callback
        end,
    }
end
local function Forbidden()
    error("VIP code must not hook, enumerate or refresh native frames")
end
hooksecurefunc, UnitFrame_Update, UnitFramePortrait_Update, securecall = Forbidden, Forbidden, Forbidden, Forbidden
app.unitFrames = { All = Forbidden, KeyOf = Forbidden }
assert(loadfile("SeamlessUnitframes/src/core/previewcharacters.lua"))("SeamlessUnitframes", app)
local module = app.previewCharacters
module:OnInitialize()
module:OnEnable()
assert(refreshes == 1)
assert(module:Get(native, "player") == nil)
assert(module:Get(native, "targettarget") == nil, "native ToT cannot impersonate the owned stand-in")
assert(module:Get(native, "focustarget") == nil)
assert(module:Get(nil, "targettarget") == nil)
assert(requests == 0, "native frames never even request catalogue data")
assert(module:Get(target, "targettarget").name == "unitframes:targettarget")
assert(module:Get(focus, "focustarget").name == "unitframes:focustarget")
for key, overlay in pairs(overlays) do
    assert(module:Get(overlay, key).name == "unitframes:" .. key)
    assert(module:Get(native, key) == nil)
    assert(module:Get(target, key) == nil)
end
assert(module:Get(overlays.player, "target") == nil, "an overlay cannot impersonate another consumer")
combat = true
event()
assert(refreshes == 2 and module:Get(target, "targettarget") == nil)
combat = false
editing = false
assert(module:Get(target, "targettarget") == nil)
editing = true
module.enabled = false
module:OnDisable()
assert(module:Get(target, "targettarget") == nil)
module.enabled = true
enabled = false
module:Refresh()
assert(module:Get(target, "targettarget") == nil)
print("Custom preview isolation tests passed")
