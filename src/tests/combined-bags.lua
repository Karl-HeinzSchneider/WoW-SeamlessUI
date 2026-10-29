-- Run from the repository root: lua src/tests/combined-bags.lua
unpack = unpack or table.unpack
local callbacks, move, panel, anchor, postHook
local layout, editing, combat, enabled = "Modern", false, false, true
local module = {
    IsEnabled = function()
        return enabled
    end,
    RegisterEvent = function() end,
}
local lib = {
    GetActiveLayoutName = function()
        return layout
    end,
    IsInEditMode = function()
        return editing
    end,
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
    AddFrame = function(_, _, callback)
        move = callback
    end,
    AddFrameSettings = function() end,
    RefreshFrameSettings = function() end,
}
callbacks = {}
local function frame(scale)
    return {
        width = 400,
        height = 500,
        shown = true,
        GetWidth = function(self)
            return self.width
        end,
        GetHeight = function(self)
            return self.height
        end,
        GetEffectiveScale = function()
            return scale
        end,
        GetRight = function()
            return 990
        end,
        GetBottom = function()
            return 100
        end,
        IsShown = function(self)
            return self.shown
        end,
        ClearAllPoints = function(self)
            self.point = nil
        end,
        SetPoint = function(self, ...)
            self.point = { ... }
        end,
        SetShown = function(self, value)
            self.shown = value
        end,
        Hide = function(self)
            self.shown = false
        end,
        SetSize = function(self, w, h)
            self.width, self.height = w, h
        end,
        SetClampedToScreen = function() end,
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function(self, _, script)
            self.onEvent = script
        end,
    }
end
UIParent = frame(1)
UIParent.width = 1200
ContainerFrameCombinedBags = frame(0.8)
local bags = ContainerFrameCombinedBags
local function nativeLayout()
    bags:ClearAllPoints()
    bags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 100)
    if postHook then
        postHook()
    end
end
UpdateContainerFrameAnchors = nativeLayout
function CreateFrame()
    anchor = frame(1)
    return anchor
end
function InCombatLockdown()
    return combat
end
function hooksecurefunc(_, callback)
    postHook = callback
end
EventRegistry = { TriggerEvent = function() end }
function LibStub()
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
local profile = { combinedBags = { layouts = {} } }
local app = {
    addon = {
        NewModule = function()
            return module
        end,
        IsEnabled = function()
            return true
        end,
    },
    db = { profile = profile, profiles = { Default = profile } },
    optionPages = { combinedBags = { config = { buttonSection = {} } } },
    blizzardPosition = {
        GetAnchorFrames = function()
            return {}
        end,
    },
    core = {
        GetEditModeLibrary = function()
            return lib
        end,
        GetEditModePositionSetting = function(_, spec)
            return spec
        end,
        RegisterEditModeOptions = function(_, _, spec)
            panel = spec
        end,
        RefreshEditModeOptions = function() end,
    },
}
assert(loadfile("SeamlessUI/src/features/combinedbags.lua"))("SeamlessUI", app)
module:OnEnable()
assert(bags.point[4] == -10, "unsaved layouts retain Blizzard's position")
assert(not anchor.shown and bags.shown, "normal bag visibility stays native")
editing = true
callbacks.enter()
assert(anchor.shown and panel.enabled(), "custom frame participates in Edit Mode")
panel.options[1].set(false)
assert(not anchor.shown and bags.shown, "Frames toggle affects only the selection preview")
panel.options[1].set(true)
move(anchor, layout, "TOPLEFT", 200, -80)
assert(profile.combinedBags.layouts.Modern.relativeTo == nil, "drag clears the previous anchor")
assert(bags.point[4] == 250 and bags.point[5] == -100, "position offsets account for native bag scale")
nativeLayout()
assert(bags.point[4] == 250, "native relayout preserves the custom position")
assert(anchor.width == 320 and anchor.height == 400, "selection fits the scaled bag")
combat = true
nativeLayout()
assert(bags.point[4] == -10, "post-hook makes no position writes in combat")
combat = false
module:OnProfileRefresh()
assert(bags.point[4] == 250, "position reapplies after combat")
callbacks.create("Copy", nil, "Modern")
assert(profile.combinedBags.layouts.Copy.x == 200)
assert(profile.combinedBags.layouts.Copy ~= profile.combinedBags.layouts.Modern)
callbacks.rename("Copy", "Renamed")
assert(profile.combinedBags.layouts.Copy == nil and profile.combinedBags.layouts.Renamed)
callbacks.delete("Renamed")
assert(profile.combinedBags.layouts.Renamed == nil)
layout = "Classic"
callbacks.layout()
assert(bags.point[4] == -10, "a different layout retains its own native position")
layout = "Modern"
callbacks.layout()
assert(bags.point[4] == 250)
module:ResetPosition()
assert(profile.combinedBags.layouts.Modern == nil and bags.point[4] == -10, "reset restores native placement")
move(anchor, layout, "CENTER", 80, 40)
enabled = false
module:OnDisable()
assert(not anchor.shown and bags.point[4] == -10, "disabling restores Blizzard positioning")
nativeLayout()
assert(bags.point[4] == -10, "disabled post-hook stays inert")
enabled = true
module:OnEnable()
assert(bags.point[4] == 100, "reenabling restores the saved position")
combat = true
enabled = false
module:OnDisable()
combat = false
anchor.onEvent(anchor)
assert(bags.point[4] == -10, "disable during combat defers restoration")
print("combined-bags: all tests passed")
