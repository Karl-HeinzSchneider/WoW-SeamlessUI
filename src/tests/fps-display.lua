-- Run from the repository root: lua src/tests/fps-display.lua
unpack = unpack or table.unpack
local callbacks, move, spec, frame, latency
local frames = {}
local frameSettings
callbacks = {}
local layout = "Modern"
local editing = false
local module = {
    IsEnabled = function()
        return true
    end,
}
local lib = {
    SettingType = { Checkbox = 1 },
    AddFrameSettings = function(_, _, settings)
        frameSettings = settings
    end,
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
        IsShown = function(self)
            return not not self.shown
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
        SetScript = function(self, name, script)
            self[name] = script
        end,
        CreateFontString = function()
            return {
                SetFontObject = function() end,
                SetPoint = function() end,
                SetTextColor = function(self, r, g, b)
                    self.color = { r, g, b }
                end,
                SetFormattedText = function(self, pattern, ...)
                    self.text = string.format(pattern, ...)
                end,
            }
        end,
    }
end
UIParent = {}
FramerateFrame = newFrame()
FramerateFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -2, 2)
CreateFrame = function()
    local created = newFrame()
    table.insert(frames, created)
    frame, latency = frames[1], frames[2]
    return created
end
local netHome, netWorld = 40, 60
GetNetStats = function()
    return 0, 0, netHome, netWorld
end
EventRegistry = { TriggerEvent = function() end }
local profile = { fpsDisplay = { layouts = {}, showLatency = false } }
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
        db = { profile = { tweaks = { showFramerateOnStartup = false } } },
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshEditModeOptions = function() end,
        RegisterEditModeOptions = function(_, _, value)
            spec = value
        end,
    },
}
dofile("src/tests/locale-support.lua")
assert(loadfile("SeamlessUI/src/features/fpsdisplay.lua"))("SeamlessUI", app)
module:OnEnable()
assert(FramerateFrame.points[1][2] == frame, "counter must follow custom anchor")
assert(not frame.shown, "anchor must hide outside Edit Mode")
editing = true
callbacks.enter()
assert(frame.shown and spec.options[1].name == "FPS display")
assert(FramerateFrame.shown, "showing Edit Mode frame must show FPS")
assert(frameSettings[1].default == false and not frameSettings[1].get())
assert(frameSettings[2].default == false and not frameSettings[2].get())
assert(not latency.shown, "latency must be off by default")
frameSettings[2].set(nil, true)
assert(profile.fpsDisplay.showLatency and latency.shown, "latency option must show latency")
latency.OnShow()
assert(latency.Text.text == "40 / 60 ms" and latency.Text.color[1] < latency.Text.color[2])
netWorld = 300
latency.OnUpdate(latency, 1)
assert(latency.Text.text == "40 / 300 ms" and latency.Text.color[1] == 1 and latency.Text.color[2] < 1)
frameSettings[2].set(nil, false)
assert(not latency.shown, "turning latency off must hide it")
move(frame, layout, "CENTER", 100, 200)
module:OnProfileRefresh()
assert(frame.points[1][1] == "CENTER" and frame.points[1][4] == 100)
spec.options[1].set(false)
assert(not frame.shown and FramerateFrame.points[1][2] == frame)
assert(not FramerateFrame.shown, "hiding preview must hide normally hidden FPS")
frameSettings[1].set(nil, true)
assert(FramerateFrame.shown, "hiding preview must preserve preferred visible FPS")
frameSettings[1].set(nil, false)
assert(not FramerateFrame.shown)
spec.options[1].set(true)
assert(FramerateFrame.shown, "showing preview must show FPS again")
editing = false
callbacks.exit()
assert(not FramerateFrame.shown, "exit must restore preferred visibility")
FramerateFrame:SetShown(true)
editing = true
callbacks.enter()
spec.options[1].set(false)
assert(FramerateFrame.shown, "normal visible state must survive hiding the preview")
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
assert(not frame.shown and not latency.shown and FramerateFrame.points[1][2] == UIParent)
assert(FramerateFrame.points[1][4] == -2, "disable must restore original anchor")
print("FPS display tests passed")
