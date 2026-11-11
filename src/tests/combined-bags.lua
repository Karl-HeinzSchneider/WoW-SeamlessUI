-- Run from the repository root: lua src/tests/combined-bags.lua
unpack = unpack or table.unpack
local callbacks, move, panel, anchor, postHook, onRegen
local layout, editing, combat, enabled = "Modern", false, false, true
local module = {
    IsEnabled = function()
        return enabled
    end,
    RegisterEvent = function(_, event, callback)
        if event == "PLAYER_REGEN_ENABLED" then
            onRegen = callback
        end
    end,
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
        scale = scale,
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
        GetEffectiveScale = function(self)
            return self.scale
        end,
        GetScale = function(self)
            return self.scale
        end,
        SetScale = function(self, value)
            self.scale = value
        end,
        GetPoint = function(self)
            if self.point then
                return unpack(self.point)
            end
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
Enum = { BagIndex = { Backpack = 0, Keyring = -2 } }
NUM_TOTAL_BAG_FRAMES = 5
function ContainerFrame_IsReagentBag(id)
    return id == 5
end
local function separateBag(id)
    local bag = frame(0.8)
    bag.bagID = id
    bag.GetBagID = function(self)
        return self.bagID
    end
    bag:SetPoint("BOTTOMRIGHT", bags, "BOTTOMLEFT", -11, 0)
    return bag
end
local keyring, reagent, regular = separateBag(-2), separateBag(5), separateBag(1)
ContainerFrameContainer = { ContainerFrames = { regular, keyring, reagent } }
local usingCombinedBags = true
ContainerFrameSettingsManager = {
    IsUsingCombinedBags = function()
        return usingCombinedBags
    end,
}
local nativeOffsetX = -10
local function nativeLayout(scale)
    bags:SetScale(scale or 0.8)
    for _, bag in ipairs(ContainerFrameContainer.ContainerFrames) do
        if bag:IsShown() then
            bag:SetScale(scale or 0.8)
            bag:SetPoint("BOTTOMRIGHT", bags, "BOTTOMLEFT", -11, 0)
        end
    end
    bags:ClearAllPoints()
    bags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", nativeOffsetX, 100)
    if postHook then
        postHook()
    end
end
function UpdateContainerFrameAnchors()
    error("the addon must leave bag layout calls to Blizzard")
end
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
    return {}, { args = {} }
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
nativeLayout()
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
assert(anchor.width == 96 and anchor.height == 36, "selection uses a compact drag target")
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
onRegen()
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
nativeOffsetX = -42
nativeLayout()
assert(bags.point[4] == 250, "a changed native position still gets the saved override")
module:ResetPosition()
assert(
    profile.combinedBags.layouts.Modern == nil and bags.point[4] == -42,
    "reset restores the latest native placement"
)
nativeOffsetX = -10
nativeLayout()
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
enabled = true
module:OnEnable()
module:ResetPosition()
local scaleOption = app.optionPages.combinedBags.config.args.size.args.scale
assert(scaleOption.get() == 1)
scaleOption.set(nil, 1.5)
assert(math.abs(bags:GetScale() - 1.2) < 0.001)
assert(anchor:GetWidth() == 96 and anchor:GetHeight() == 36, "the drag target stays compact at any bag scale")
assert(math.abs(keyring:GetScale() - 1.2) < 0.001 and math.abs(reagent:GetScale() - 1.2) < 0.001)
assert(regular:GetScale() == 0.8, "other containers keep their native scale")
module:Refresh()
assert(math.abs(keyring:GetScale() - 1.2) < 0.001, "refresh does not compound separate bag scaling")
assert(math.abs(bags.point[4] * bags:GetScale() - -8) < 0.001, "scale preserves native anchor offsets")
nativeLayout(1)
assert(bags:GetScale() == 1.5, "scale follows Blizzard's latest native scale")
assert(keyring:GetScale() == 1.5 and reagent:GetScale() == 1.5, "native layouts reapply scale to separate bags")
keyring.shown = false
module:Refresh()
assert(keyring:GetScale() == 1, "hidden container restores before reuse")
keyring.shown = true
nativeLayout(1)
assert(keyring:GetScale() == 1.5, "reopened keyring inherits the selected scale")
reagent.bagID = 1
module:Refresh()
assert(reagent:GetScale() == 1, "a container reused for another bag restores its native scale")
reagent.bagID = 5
module:Refresh()
assert(reagent:GetScale() == 1.5)
bags.shown = false
module:Refresh()
assert(keyring:GetScale() == 1.5, "a separate bag can open on its own in combined mode")
usingCombinedBags = false
regular:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 100)
keyring:SetPoint("BOTTOMRIGHT", regular, "BOTTOMLEFT", -11, 0)
reagent:SetPoint("BOTTOMRIGHT", keyring, "TOPRIGHT", 0, 4)
move(anchor, layout, "CENTER", 90, 45)
assert(regular:GetScale() == 1.5, "individual inventory bags use the scale")
assert(keyring:GetScale() == 1.5 and reagent:GetScale() == 1.5, "separate bags also scale in individual mode")
assert(
    regular.point[1] == "CENTER" and regular.point[2] == UIParent,
    "saved anchor applies to the first individual bag"
)
assert(keyring.point[2] == regular and reagent.point[2] == keyring, "the native layout stays chained to the first bag")
assert(bags:GetScale() == 1, "the inactive combined backpack restores its scale")
usingCombinedBags = true
regular.shown = false
bags.shown = true
nativeLayout(1)
assert(bags.point[1] == "CENTER", "switching modes uses the same saved anchor")
assert(regular.point[1] == "BOTTOMRIGHT" and regular:GetScale() == 1, "switching restores the inactive root")
module:ResetPosition()
combat = true
scaleOption.set(nil, 2)
assert(scaleOption.get() == 1.5)
reagent.protected = true
nativeLayout(1)
assert(bags:GetScale() == 1.5 and keyring:GetScale() == 1.5, "opening bags in combat preserves their scale")
assert(reagent:GetScale() == 1, "protected bags defer scale changes")
combat = false
onRegen()
assert(reagent:GetScale() == 1.5, "protected bags catch up after combat")
scaleOption.set(nil, 1)
assert(keyring:GetScale() == 1 and reagent:GetScale() == 1, "default restores separate bags")
assert(bags:GetScale() == 1 and bags.point[4] == -10, "default restores the latest native scale and anchor")
scaleOption.set(nil, 1.5)
combat = true
enabled = false
module:OnDisable()
assert(bags:GetScale() == 1.5)
combat = false
anchor.onEvent(anchor)
assert(bags:GetScale() == 1, "disable during combat defers scale restoration")
assert(keyring:GetScale() == 1 and reagent:GetScale() == 1, "deferred disable restores separate bags")
enabled = true
module:OnEnable()
local secret = setmetatable({}, {
    __mul = function()
        error("secret offset used in arithmetic")
    end,
})
function issecretvalue(value)
    return rawequal(value, secret)
end
scaleOption.set(nil, 1)
local setScale = bags.SetScale
bags.SetScale = function()
    error("scale changed while the bag anchor was secret")
end
bags.point[4] = secret
scaleOption.set(nil, 1.5)
bags.SetScale = setScale
assert(bags:GetScale() == 1, "secret anchors leave the bag untouched")
nativeLayout(1)
assert(bags:GetScale() == 1.5, "a readable native layout allows scaling again")
print("combined-bags: all tests passed")
