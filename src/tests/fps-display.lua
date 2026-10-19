-- Run from the repository root: lua src/tests/fps-display.lua
unpack = unpack or table.unpack
local callbacks, move, spec, frame
callbacks = {}
local layout = "Modern"
local editing = false
local module = {
    IsEnabled = function()
        return true
    end,
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
}
local function newFrame()
    return {
        points = {},
        SetSize = function() end,
        SetClampedToScreen = function() end,
        ClearAllPoints = function(self)
            self.points = {}
        end,
        SetPoint = function(self, ...)
            table.insert(self.points, { ... })
        end,
        SetShown = function(self, shown)
            self.shown = shown
        end,
        Hide = function(self)
            self.shown = false
        end,
        GetNumPoints = function(self)
            return #self.points
        end,
        GetPoint = function(self, index)
            return unpack(self.points[index])
        end,
    }
end
UIParent = {}
FramerateFrame = newFrame()
FramerateFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -2, 2)
CreateFrame = function()
    frame = newFrame()
    return frame
end
EventRegistry = { TriggerEvent = function() end }
local profile = { fpsDisplay = { layouts = {} } }
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
    core = {
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshEditModeOptions = function() end,
        RegisterEditModeOptions = function(_, _, value)
            spec = value
        end,
    },
}
assert(loadfile("SeamlessUI/src/features/fpsdisplay.lua"))("SeamlessUI", app)
module:OnEnable()
assert(FramerateFrame.points[1][2] == frame, "counter must follow custom anchor")
assert(not frame.shown, "anchor must hide outside Edit Mode")
editing = true
callbacks.enter()
assert(frame.shown and spec.options[1].name == "FPS display")
move(frame, layout, "CENTER", 100, 200)
module:OnProfileRefresh()
assert(frame.points[1][1] == "CENTER" and frame.points[1][4] == 100)
spec.options[1].set(false)
assert(not frame.shown and FramerateFrame.points[1][2] == frame)
spec.options[1].set(true)
callbacks.create("Copy", nil, "Modern")
assert(profile.fpsDisplay.layouts.Copy.x == 100)
assert(profile.fpsDisplay.layouts.Copy ~= profile.fpsDisplay.layouts.Modern)
callbacks.rename("Copy", "Renamed")
assert(profile.fpsDisplay.layouts.Renamed and not profile.fpsDisplay.layouts.Copy)
callbacks.delete("Renamed")
assert(not profile.fpsDisplay.layouts.Renamed)
layout = "Classic"
callbacks.layout()
assert(frame.points[1][1] == "BOTTOMRIGHT", "new layouts must use default position")
app.db.profile = { fpsDisplay = { layouts = {} } }
layout = "Modern"
module:OnProfileRefresh()
assert(frame.points[1][1] == "BOTTOMRIGHT", "profiles must have independent positions")
module:OnDisable()
assert(not frame.shown and FramerateFrame.points[1][2] == UIParent)
assert(FramerateFrame.points[1][4] == -2, "disable must restore original anchor")
print("FPS display tests passed")
