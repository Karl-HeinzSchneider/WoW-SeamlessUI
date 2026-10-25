-- Run from the repository root: lua src/tests/fps-display.lua
unpack = unpack or table.unpack
local callbacks, move, spec, frame, display
local frames = {}
local frameSettings, positionSpec
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
    RefreshFrameSettings = function() end,
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
        GetEffectiveScale = function(self)
            return self.parent == WorldFrame and 1.5 or 1
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
                GetTextColor = function()
                    return 1, 1, 1
                end,
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
hooksecurefunc = function(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end
UIParent = {}
WorldFrame = {}
FramerateFrame = newFrame()
FramerateFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -2, 2)
FramerateFrame.FramerateText = {
    SetFormattedText = function(self, pattern, ...)
        self.text = string.format(pattern, ...)
    end,
    SetText = function(self, text)
        self.text = text
    end,
    GetText = function(self)
        return self.text
    end,
}
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
    blizzardPosition = {
        GetAnchorFrames = function()
            return { { value = "UIParent", text = "UIParent" }, { value = "PlayerFrame", text = "Player frame" } }
        end,
    },
    core = {
        RegisterEditModeSettings = function() end,
        db = { profile = { tweaks = { showFramerateOnStartup = false } } },
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshEditModeOptions = function() end,
        GetEditModePositionSetting = function(_, value)
            positionSpec = value
            return { name = "Position", kind = "position" }
        end,
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
assert(display.parent == WorldFrame, "display must share the counter's parent and scale")
assert(frame.width == display.width * 1.5 and frame.height == display.height * 1.5, "anchor must match the display")
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
assert(frameSettings[3].default == false and not frameSettings[3].get())
frameSettings[3].set(nil, true)
local r, g, b = unpack(display.LatencyText.color)
assert(profile.fpsDisplay.whiteLatency and r == 1 and g == 1 and b == 1, "white latency option must use white")
frameSettings[3].set(nil, false)
assert(display.LatencyText.color[2] < 1, "latency colors must return")
GetFramerate = function()
    return 119.6
end
assert(frameSettings[4].default == false and not frameSettings[4].get())
display.OnUpdate(display, 1)
assert(display.FramerateText.text == "119.6")
FramerateFrame.FramerateText:SetFormattedText("%.1f", 119.6)
assert(FramerateFrame.FramerateText.text == "119.6", "native counter must keep decimals by default")
frameSettings[4].set(nil, true)
assert(profile.fpsDisplay.roundFramerate and display.FramerateText.text == "120", "display must round FPS")
FramerateFrame.FramerateText:SetFormattedText("%.1f", 119.6)
assert(FramerateFrame.FramerateText.text == "120", "native counter must round FPS")
FramerateFrame.FramerateText:SetFormattedText("%.1f (CPU)", 59.4)
assert(FramerateFrame.FramerateText.text == "59 (CPU)", "rounding must keep the counter's suffix")
frameSettings[4].set(nil, false)
assert(display.FramerateText.text == "119.6")
FramerateFrame:SetShown(false)
assert(not display.shown, "display must hide with the counter")
FramerateFrame:SetShown(true)
assert(display.shown, "display must show with the counter")
frameSettings[2].set(nil, false)
assert(not display.shown and FramerateFrame.alpha == 1, "turning latency off must restore the counter")
assert(frame.width == 120, "anchor must return to its normal size")
assert(frameSettings[5].name == "Position", "the Position section follows the frame's settings")
PlayerFrame = newFrame()
PlayerFrame.IsObjectType = function(_, kind)
    return kind == "Frame"
end
positionSpec.set("relativeTo", "PlayerFrame")
positionSpec.set("relativePoint", "TOPLEFT")
positionSpec.set("x", 40)
assert(frame.points[1][1] == "BOTTOMRIGHT" and frame.points[1][2] == PlayerFrame and frame.points[1][3] == "TOPLEFT")
assert(frame.points[1][4] == 40 and positionSpec.get("y") == 2)
positionSpec.set("relativeTo", "MissingFrame")
assert(frame.points[1][2] == UIParent, "unknown anchor frames fall back to UIParent")
move(frame, layout, "CENTER", 100, 200)
module:OnProfileRefresh()
assert(frame.points[1][1] == "CENTER" and frame.points[1][4] == 100)
assert(frame.points[1][2] == UIParent and frame.points[1][3] == "CENTER", "dragging anchors to UIParent again")
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
