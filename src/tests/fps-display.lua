-- Run from the repository root: lua src/tests/fps-display.lua
unpack = unpack or table.unpack
local callbacks, move, spec, frame, display
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
        SetSize = function(self, width, height)
            self.width, self.height = width, height
        end,
        SetClampedToScreen = function() end,
        ClearAllPoints = function(self)
            self.points = {}
        end,
        SetPoint = function(self, ...)
            table.insert(self.points, { ... })
        end,
        SetShown = function(self, shown)
            self.shown = shown
            local hook = self.hooks and self.hooks[shown and "OnShow" or "OnHide"]
            if hook then
                hook(self)
            end
        end,
        HookScript = function(self, name, script)
            self.hooks = self.hooks or {}
            self.hooks[name] = script
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
        SetAlpha = function(self, alpha)
            self.alpha = alpha
        end,
        GetWidth = function(self)
            return self.width or 0
        end,
        GetHeight = function(self)
            return self.height or 0
        end,
        CreateFontString = function()
            return {
                SetFontObject = function() end,
                SetPoint = function() end,
                SetJustifyH = function() end,
                SetText = function(self, text)
                    self.text = text
                end,
                GetStringWidth = function(self)
                    return #self.text * 6
                end,
                GetStringHeight = function()
                    return 12
                end,
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
CreateFrame = function(_, _, parent)
    local created = newFrame()
    created.parent = parent
    table.insert(frames, created)
    frame, display = frames[1], frames[2]
    return created
end
local netHome, netWorld = 40, 60
GetFramerate = function()
    return 1234.56
end
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
assert(not display.shown and FramerateFrame.alpha ~= 0, "latency must be off by default")
frameSettings[2].set(nil, true)
assert(profile.fpsDisplay.showLatency and display.shown, "latency option must show the two-row display")
assert(FramerateFrame.alpha == 0, "the two-row display must replace the native counter")
assert(display.parent ~= FramerateFrame, "display must not resize the counter as its child")
assert(display.points[1][2] == frame, "display must follow the custom anchor")
assert(frame.width == display.width and frame.height == display.height, "anchor must match the display")
assert(display.height == 26, "display must have two rows")
display.OnShow()
assert(display.FramerateText.text == "999.9", "framerate must be capped at 999.9")
assert(display.LatencyText.text == "60" and display.LatencyText.color[1] < display.LatencyText.color[2])
netWorld = 300
display.OnUpdate(display, 1)
assert(display.LatencyText.text == "300" and display.LatencyText.color[1] == 1)
netWorld = 5000
display.OnUpdate(display, 1)
assert(display.LatencyText.text == "999", "latency must be capped at 999")
FramerateFrame:SetShown(false)
assert(not display.shown, "display must hide with the counter")
FramerateFrame:SetShown(true)
assert(display.shown, "display must show with the counter")
frameSettings[2].set(nil, false)
assert(not display.shown and FramerateFrame.alpha == 1, "turning latency off must restore the counter")
assert(frame.width == 120, "anchor must return to its normal size")
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
assert(not frame.shown and not display.shown and FramerateFrame.points[1][2] == UIParent)
assert(FramerateFrame.points[1][4] == -2, "disable must restore original anchor")
print("FPS display tests passed")
