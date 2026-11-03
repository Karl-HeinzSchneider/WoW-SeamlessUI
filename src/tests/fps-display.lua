-- Run from the repository root: lua src/tests/fps-display.lua
unpack = unpack or table.unpack
local callbacks, move, spec, frame, display
local frames = {}
local frameSettings, positionSpec
callbacks = {}
local layout = "Modern"
local editing = false
local enabled = true
local module = {
    IsEnabled = function()
        return enabled
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
        EnableKeyboard = function(self, value)
            self.keyboardEnabled = value
        end,
        SetPropagateKeyboardInput = function(self, value)
            self.propagate = value
        end,
        Show = function(self)
            self.shown = true
        end,
        SetHeight = function(self, height)
            self.height = height
        end,
        RegisterEvent = function(self, event)
            self.events = self.events or {}
            self.events[event] = true
        end,
        UnregisterEvent = function(self, event)
            if self.events then
                self.events[event] = nil
            end
        end,
        GetAlpha = function(self)
            return self.alpha or 1
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
                SetShown = function(self, shown)
                    self.shown = shown
                end,
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
hooksecurefunc = function()
    error("FPS must not install native hooks")
end
UIParent = {}
WorldFrame = {}
-- Fail on every native access, including reads, while suppression is off.
local untouchedNative = setmetatable({}, {
    __index = function(_, key)
        error("unexpected native access: " .. key)
    end,
    __newindex = function(_, key)
        error("unexpected native write: " .. key)
    end,
})
FramerateFrame = untouchedNative
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
        GetCustomEditModeVisibility = dofile("src/tests/settings-support.lua").customVisibility,
        db = { profile = { tweaks = { showFramerateOnStartup = false } } },
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshEditModeOptions = function() end,
        GetEditModeButtonSection = dofile("src/tests/settings-support.lua").buttonSection,
        GetEditModePositionButton = dofile("src/tests/settings-support.lua").positionButton,
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
app.optionPages = {}
app.core.GetPositionOptions = function(_, binding)
    return { type = "group", args = {}, editModePosition = binding }, { type = "group", args = {}, editModeSize = true }
end
app.core.RefreshOptions = function() end
assert(loadfile("SeamlessUI/src/options/fpsDisplay.lua"))("SeamlessUI", app)
local support = dofile("src/tests/settings-support.lua")
support.editModePages(app.core, "SeamlessUI", app)
local bindingKey = "CTRL-R"
local inputPrefix = "CTRL-"
local focus
GetCurrentKeyBoardFocus = function()
    return focus
end
GetBindingFullInput = function(key)
    return inputPrefix .. key
end
GetBindingAction = function(input, checkOverride)
    assert(checkOverride, "respect binding overrides")
    return input == bindingKey and "TOGGLEFPS" or "OTHER"
end
wipe = function(value)
    for key in pairs(value) do
        value[key] = nil
    end
end
module:OnEnable()
local keyboard = frames[3]
assert(keyboard.keyboardEnabled and keyboard.propagate and keyboard.shown)
-- A keyboard toggle must remain independent of settings and Edit Mode, including in combat.
local function pressKey(key)
    local oldSet, oldRefresh = module.SetOption, module.Refresh
    local oldOptions, oldEditMode = app.core.RefreshOptions, app.core.RefreshEditModeOptions
    local oldClear, oldPoint = frame.ClearAllPoints, frame.SetPoint
    local function forbidden()
        error("keybind must only toggle display visibility")
    end
    module.SetOption, module.Refresh = forbidden, forbidden
    app.core.RefreshOptions, app.core.RefreshEditModeOptions = forbidden, forbidden
    frame.ClearAllPoints, frame.SetPoint = forbidden, forbidden
    keyboard.OnKeyDown(keyboard, key)
    module.SetOption, module.Refresh = oldSet, oldRefresh
    app.core.RefreshOptions, app.core.RefreshEditModeOptions = oldOptions, oldEditMode
    frame.ClearAllPoints, frame.SetPoint = oldClear, oldPoint
end
local rows = support.pageRows(frameSettings)
assert(not frame.shown and not display.shown, "startup defaults to hidden")
assert(display.parent == WorldFrame and display.points[1][2] == frame)
assert(display.height == 12 and not display.LatencyText.shown, "FPS alone uses one row")
assert(rows.visible.default() == false and not rows.visible.get())
rows.visible.set(true)
assert(display.shown and not frame.shown, "custom visibility works outside Edit Mode")
assert(display.FramerateText.text == "999.9")
rows.visible.set(false)
pressKey("R")
assert(display.shown and rows.visible.get(), "Ctrl+R shows custom FPS while native access is forbidden")
pressKey("R")
assert(display.shown, "held-key repeats do not toggle again")
keyboard.OnKeyUp(keyboard, "R")
pressKey("R")
assert(not display.shown, "next press hides custom FPS")
keyboard.OnKeyUp(keyboard, "R")
bindingKey = "ALT-F"
pressKey("R")
assert(not display.shown, "old key stops working after reassignment")
keyboard.OnKeyUp(keyboard, "R")
inputPrefix = "ALT-"
focus = {}
pressKey("F")
assert(not display.shown, "typing focus does not toggle FPS")
keyboard.OnKeyUp(keyboard, "F")
focus = nil
pressKey("F")
assert(display.shown, "remapped TOGGLEFPS key works immediately")
keyboard.OnKeyUp(keyboard, "F")
rows.visible.set(false)
editing = true
callbacks.enter()
assert(frame.shown and display.shown and spec.options[1].name == "FPS display")
pressKey("F")
assert(not display.shown and frame.shown, "key hides the counter directly even during preview")
keyboard.OnKeyUp(keyboard, "F")
pressKey("F")
assert(display.shown and frame.shown, "key shows the counter without touching preview selection")
keyboard.OnKeyUp(keyboard, "F")
rows.visible.set(false)
assert(rows.startup.default() == false and not rows.startup.get())
assert(rows.showLatency.default() == false and not rows.showLatency.get())
rows.showLatency.set(true)
assert(profile.fpsDisplay.showLatency and display.shown and display.LatencyText.shown)
assert(frame.width == display.width * 1.5 and frame.height == display.height * 1.5)
assert(display.height == 26, "latency uses two rows")
display.OnShow()
assert(display.LatencyText.text == "60" and display.LatencyText.color[1] < display.LatencyText.color[2])
netWorld = 300
display.OnUpdate(display, 0.25)
assert(display.LatencyText.text == "300" and display.LatencyText.color[1] == 1)
netWorld = 5000
display.OnUpdate(display, 0.1)
assert(display.LatencyText.text == "300", "updates wait for the independent interval")
display.OnUpdate(display, 0.15)
assert(display.LatencyText.text == "999", "latency is capped")
rows.whiteLatency.set(true)
local r, g, b = unpack(display.LatencyText.color)
assert(r == 1 and g == 1 and b == 1)
rows.whiteLatency.set(false)
assert(display.LatencyText.color[2] < 1)
GetFramerate = function()
    return 119.6
end
display.OnUpdate(display, 1)
assert(display.FramerateText.text == "119.6")
rows.roundFramerate.set(true)
assert(display.FramerateText.text == "120")
rows.roundFramerate.set(false)
assert(display.FramerateText.text == "119.6")
rows.showLatency.set(false)
assert(display.shown and display.height == 12 and not display.LatencyLabel.shown)
assert(positionSpec, "Position is available")
PlayerFrame = newFrame()
PlayerFrame.IsObjectType = function(_, kind)
    return kind == "Frame"
end
positionSpec.set("relativeTo", "PlayerFrame")
positionSpec.set("relativePoint", "TOPLEFT")
positionSpec.set("x", 40)
assert(frame.points[1][2] == PlayerFrame and frame.points[1][3] == "TOPLEFT")
assert(frame.points[1][4] == 40 and positionSpec.get("y") == 2)
positionSpec.set("relativeTo", "MissingFrame")
assert(frame.points[1][2] == UIParent)
move(frame, layout, "CENTER", 100, 200)
module:OnProfileRefresh()
assert(frame.points[1][1] == "CENTER" and frame.points[1][4] == 100)
assert(frame.points[1][2] == UIParent and frame.points[1][3] == "CENTER")
spec.options[1].set(false)
assert(not frame.shown and not display.shown, "preview is independent of normal visibility")
rows.visible.set(true)
assert(display.shown and not frame.shown)
rows.visible.set(false)
spec.options[1].set(true)
assert(display.shown)
editing = false
callbacks.exit()
assert(not display.shown, "preview does not persist after Edit Mode")
rows.startup.set(true)
assert(rows.startup.get() and display.shown)
callbacks.create("Copy", nil, "Modern")
assert(profile.fpsDisplay.layouts.Copy.x == 100)
assert(profile.fpsDisplay.layouts.Copy ~= profile.fpsDisplay.layouts.Modern)
callbacks.rename("Copy", "Renamed")
assert(profile.fpsDisplay.layouts.Renamed and not profile.fpsDisplay.layouts.Copy)
callbacks.delete("Renamed")
assert(not profile.fpsDisplay.layouts.Renamed)
layout = "Classic"
callbacks.layout()
assert(frame.points[1][1] == "BOTTOMRIGHT")
app.db.profile = { fpsDisplay = { layouts = {} } }
layout = "Modern"
module:OnProfileRefresh()
assert(frame.points[1][1] == "BOTTOMRIGHT")
enabled = false
module:OnDisable()
assert(not display.shown and not frame.shown and not keyboard.shown)
pressKey("F")
assert(not display.shown, "disabled module ignores key input")
keyboard.OnKeyUp(keyboard, "F")
-- No native frame at all is required for custom startup, updates or preview.
FramerateFrame = nil
enabled = true
module:OnEnable()
assert(display.shown and rows.visible.get(), "startup preference shows custom FPS before any keypress")
pressKey("F")
assert(not display.shown and rows.startup.get(), "key can hide startup FPS without changing the saved option")
keyboard.OnKeyUp(keyboard, "F")
pressKey("F")
assert(display.shown and rows.startup.get())
keyboard.OnKeyUp(keyboard, "F")
assert(rows.hideBlizzard.default() == false)
rows.hideBlizzard.set(true)
assert(display.events.ADDON_LOADED, "suppression waits for a late native addon")
local native = newFrame()
native:SetAlpha(0.6)
native:SetShown(true)
FramerateFrame = native
display.OnEvent()
assert(native.alpha == 0 and native.shown and not display.events.ADDON_LOADED)
native:SetShown(false)
assert(display.shown, "native visibility cannot hide the custom frame")
rows.hideBlizzard.set(false)
assert(native.alpha == 0.6 and not native.shown, "restore alpha without changing native visibility")
rows.hideBlizzard.set(true)
native:SetAlpha(0.4)
module:OnProfileRefresh()
assert(native.alpha == 0.4, "refresh does not reclaim an externally changed alpha")
rows.hideBlizzard.set(false)
assert(native.alpha == 0.4, "external alpha changes survive restoration")
rows.hideBlizzard.set(true)
app.db.profile = profile
module:OnProfileRefresh()
assert(native.alpha == 0.4, "profile switching restores owned suppression")
rows.hideBlizzard.set(true)
enabled = false
module:OnDisable()
assert(native.alpha == 0.4 and not native.shown)
-- Disabled settings cannot reapply suppression or show the display.
module:SetOption("visible", true)
assert(not display.shown)
profile.fpsDisplay.hideBlizzard = false
FramerateFrame = untouchedNative
enabled = true
module:OnEnable()
assert(display.shown)
rows.startup.set(false)
assert(not display.shown)
enabled = false
module:OnDisable()
-- Core must not show the native counter before the custom module starts.
SlashCmdList = {}
local coreApp = {
    logger = {},
    addon = {
        NewModule = function(_, _, value)
            return value
        end,
    },
    db = { profile = { tweaks = { showFramerateOnStartup = true } } },
}
assert(loadfile("Seamless/src/core/tweaks.lua"))("Seamless", coreApp)
coreApp.tweaks:OnEnable()
coreApp.tweaks:OnDisable()
print("FPS display tests passed")
