-- Cosmetic preview frame boundaries: lua src/tests/preview-unitframes.lua
local enabled, editing, combat = true, true, false
local event
local refreshes, requests = 0, 0
local target, focus, native = {}, {}, {}
local app = { addon = {}, core = {}, totMover = { movers = { targettarget = target, focustarget = focus } } }
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
local callbacks = {}
function app.core:GetEditModeLibrary()
    return {
        RegisterCallback = function(_, name, callback)
            callbacks[name] = callback
        end,
    }
end
for _, name in ipairs({ "nameDisplay", "classIcon", "healthColor" }) do
    app[name] = { Refresh = function() end }
end
PlayerFrame, TargetFrame, FocusFrame = {}, {}, {}
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
    error("VIP controller must not hook or call native frame updaters")
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
assert(requests == 0, "unrecognized frames never request catalogue data")
for key, frame in pairs({ player = PlayerFrame, target = TargetFrame, focus = FocusFrame }) do
    assert(module:Get(frame, key).name == "unitframes:" .. key)
    assert(module:Get(frame, "pet") == nil)
end
editing = false
callbacks.exit()
assert(module:Get(PlayerFrame, "player") == nil)
editing = true
callbacks.enter()
assert(module:Get(target, "targettarget").name == "unitframes:targettarget")
assert(module:Get(focus, "focustarget").name == "unitframes:focustarget")
combat = true
event()
assert(refreshes == 4 and module:Get(target, "targettarget") == nil)
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
print("Cosmetic preview boundary tests passed")
