-- Run from the repository root: lua src/tests/ui-framerate.lua
-- Exercises the SeamlessUI framerate module against stubbed frames and LibEditMode.

local function newFrame(width, height, scale)
    local frame = { shown = false, width = width or 0, height = height or 0, scale = scale or 1, scripts = {} }
    function frame:SetSize(w, h)
        self.width, self.height = w, h
    end
    function frame:GetSize()
        return self.width, self.height
    end
    function frame:GetWidth()
        return self.width
    end
    function frame:GetHeight()
        return self.height
    end
    function frame:GetEffectiveScale()
        return self.scale
    end
    function frame:ClearAllPoints()
        self.point = nil
    end
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:Show()
        self.shown = true
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:SetShown(shown)
        self.shown = not not shown
    end
    function frame:IsShown()
        return self.shown
    end
    function frame:SetClampedToScreen() end
    function frame:HookScript(name, callback)
        self.scripts[name] = callback
    end
    return frame
end

UIParent = newFrame(1920, 1080, 0.5)
WorldFrame = newFrame(1920, 1080, 1)
FramerateFrame = newFrame(80, 14, 1)
function CreateFrame(_, _, parent)
    return newFrame(0, 0, parent.scale)
end
local hiddenDialogs = 0
EventRegistry = {
    TriggerEvent = function(_, event)
        assert(event == "EditModeExternal.hideDialog")
        hiddenDialogs = hiddenDialogs + 1
    end,
}

local editing, callbacks = false, {}
local added, settings
local lib = {
    SettingType = { Checkbox = 1 },
    IsInEditMode = function()
        return editing
    end,
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
    AddFrame = function(_, frame, callback, default, name)
        added = { frame = frame, callback = callback, default = default, name = name }
    end,
    AddFrameSettings = function(_, _, list)
        settings = list
    end,
    RefreshFrameSettings = function() end,
}

local coreProfiles = {
    Default = { tweaks = { showFramerateOnStartup = true, reloadShortcut = false } },
    Other = { tweaks = { showFramerateOnStartup = false } },
    Untouched = { tweaks = { reloadShortcut = false } },
}
local registration
local core = {
    db = { profiles = coreProfiles },
    GetEditModeLibrary = function()
        return lib
    end,
    RegisterEditModeOptions = function(_, id, spec)
        assert(id == "SeamlessUI")
        registration = spec
    end,
    RefreshEditModeOptions = function() end,
    RefreshOptions = function() end,
}

local module
local profile = { framerate = { movable = false, showOnStartup = false, point = "BOTTOMRIGHT", x = -2, y = 2 } }
local app = {
    core = core,
    db = { profile = profile, profiles = { Default = profile } },
    addon = {
        -- Like AceAddon: a new object; a table argument would only become its prototype.
        NewModule = function(_, _, prototype)
            module = setmetatable({}, { __index = prototype })
            function module:IsEnabled()
                return true
            end
            return module
        end,
    },
}
assert(loadfile("SeamlessUI/src/features/framerate.lua"))("SeamlessUI", app)

-- Migration moves true values into the same-named profile and clears every Core copy.
module:OnInitialize()
assert(profile.framerate.showOnStartup == true)
assert(app.db.profiles.Other == nil, "false needs no UI profile")
assert(coreProfiles.Default.tweaks.showFramerateOnStartup == nil)
assert(coreProfiles.Default.tweaks.reloadShortcut == false)
assert(coreProfiles.Other.tweaks.showFramerateOnStartup == nil)

-- Startup visibility applies on enable; movement stays off by default.
module:OnEnable()
assert(FramerateFrame.shown)
assert(added == nil and not FramerateFrame.point, "No mover or re-anchoring until enabled")
FramerateFrame:Hide()

-- Enabling movement registers one mover and anchors the counter to it.
module:Set("movable", true)
local mover = added.frame
assert(added.name == "Framerate" and added.default.point == "BOTTOMRIGHT")
assert(mover.shown and mover.point[1] == "BOTTOMRIGHT" and mover.point[2] == UIParent)
assert(FramerateFrame.point[2] == mover)
assert(mover.width == 160 and mover.height == 28, "Mover converts WorldFrame size to UIParent scale")
FramerateFrame:SetSize(60, 14)
FramerateFrame.scripts.OnSizeChanged()
assert(mover.width == 160, "Mover never shrinks while the text changes")
assert(not FramerateFrame.shown)

-- Edit Mode previews the counter and restores the player's choice on exit.
editing = true
callbacks.enter()
assert(FramerateFrame.shown)
added.callback(mover, "Modern", "TOPLEFT", 10, -20)
assert(profile.framerate.point == "TOPLEFT" and profile.framerate.x == 10 and profile.framerate.y == -20)
editing = false
callbacks.exit()
assert(not FramerateFrame.shown)
module:Refresh()
assert(mover.point[1] == "TOPLEFT" and mover.point[4] == 10)

-- The dialog checkbox and the shared panel toggles write the same profile values.
assert(settings[1].get() == true)
settings[1].set("Modern", false)
assert(profile.framerate.showOnStartup == false)
assert(registration.enabled())
registration.options[2].set(true)
assert(registration.options[2].get() == true)

-- Turning movement off hides the mover and restores the client's default anchor.
editing = true
callbacks.enter()
registration.options[1].set(false)
assert(hiddenDialogs == 1)
assert(not mover.shown)
local point = FramerateFrame.point
assert(point[1] == "BOTTOMRIGHT" and point[2] == WorldFrame and point[4] == -2 and point[5] == 2)
assert(not FramerateFrame.shown, "Preview ends once the counter can no longer move")

module:OnDisable()
print("PASS: framerate migration, mover anchoring, Edit Mode preview and options")
