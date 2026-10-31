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
    SettingType = { Checkbox = 1 },
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
        IsProtected = function(self)
            return self.protected or false
        end,
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
        GetEditModePageSettings = function(_, addonName, page)
            assert(addonName == "SeamlessUI" and page == "combinedBags", "Edit Mode reads the frame's page")
            return {}
        end,
        RegisterEditModeOptions = function(_, _, spec)
            panel = spec
        end,
        RefreshEditModeOptions = function() end,
    },
}
assert(loadfile("SeamlessUI/src/features/combinedbags.lua"))("SeamlessUI", app)
local support = dofile("src/tests/settings-support.lua")
app.core.GetCustomEditModeVisibility = support.customVisibility
app.core.GetEditModeButtonSection = support.buttonSection
app.core.GetEditModePositionButton = support.positionButton
app.core.GetPositionOptions = function()
    return {}
end
app.core.RefreshOptions = function() end
assert(loadfile("SeamlessUI/src/options/combinedBags.lua"))("SeamlessUI", app)
assert(app.optionPages.combinedBags.defaults.profile.combinedBags.positionInCombat == false)
EditModeUtil = {
    GetRightActionBarWidth = function()
        return 40
    end,
}
CONTAINER_OFFSET_Y = 85
module:OnEnable()
assert(bags.point[4] == -10, "unsaved layouts retain Blizzard's position")
-- The declared default is the client's own placement formula, never the bag's live position.
local binding = module:GetPositionBinding()
assert(binding.default("point") == "BOTTOMRIGHT" and binding.default("relativePoint") == "BOTTOMRIGHT")
assert(binding.default("relativeTo") == "UIParent")
assert(binding.default("x") == -50 and binding.default("y") == 85, "UpdateContainerFrameAnchors' offsets")
assert(not anchor.shown and bags.shown, "normal bag visibility stays native")
editing = true
callbacks.enter()
assert(not anchor.shown and not panel.options[1].get() and panel.enabled(), "Edit Mode preview defaults to off")
panel.options[1].set(true)
assert(anchor.shown, "custom frame participates in Edit Mode when enabled")
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
local combatOption = app.optionPages.combinedBags.config.args.positionInCombat
local outlinePoint = anchor.point
combatOption.set(nil, true)
assert(combatOption.get() and bags.point[4] == 250, "option applies the saved position during combat")
nativeLayout()
assert(bags.point[4] == 250 and bags.point[5] == -100, "opening in combat retains scaled saved offsets")
assert(anchor.point == outlinePoint, "combat positioning never updates the Edit Mode outline")
bags.protected = true
nativeLayout()
assert(bags.point[4] == -10, "protected bag frames are never repositioned in combat")
bags.protected = false
UIParent.protected = true
nativeLayout()
assert(bags.point[4] == 250, "a protected UIParent does not prevent positioning an unprotected bag")
UIParent.protected = false
combatOption.set(nil, false)
nativeLayout()
assert(bags.point[4] == -10, "turning the option off restores the existing combat behavior")
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
