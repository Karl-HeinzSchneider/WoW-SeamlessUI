-- Run from the repository root: lua src/tests/bag-style.lua
unpack = unpack or table.unpack
local combat, hookCount, maskCount = false, 0, 0
InCombatLockdown = function()
    return combat
end
wipe = function(value)
    for key in pairs(value) do
        value[key] = nil
    end
end
GetInventoryItemTexture = function(_, id)
    return id ~= 2 and "equipped" or nil
end
local function region()
    local r = {
        width = 45,
        height = 45,
        alpha = 1,
        anchors = {},
        coords = { 0, 1, 0, 1 },
        rotation = 0,
        shown = true,
        masks = {},
    }
    function r:GetWidth()
        return self.width
    end
    function r:GetHeight()
        return self.height
    end
    function r:SetSize(w, h)
        assert(not combat or not self:IsProtected())
        self.width, self.height = w, h
    end
    function r:IsProtected()
        return self.protected or false
    end
    function r:GetAlpha()
        return self.alpha
    end
    function r:SetAlpha(a)
        self.alpha = a
    end
    function r:GetNumPoints()
        return #self.anchors
    end
    function r:GetPoint(i)
        return unpack(self.anchors[i])
    end
    function r:SetPoint(...)
        self.anchors[#self.anchors + 1] = { ... }
    end
    function r:ClearAllPoints()
        self.anchors = {}
    end
    function r:SetAllPoints(parent)
        self.anchors = { { "TOPLEFT", parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0 } }
    end
    function r:GetTexture()
        return self.texture
    end
    function r:SetTexture(texture)
        self.texture, self.atlas = texture, nil
    end
    function r:GetAtlas()
        return self.atlas
    end
    function r:SetAtlas(atlas)
        self.atlas, self.texture = atlas, atlas
        self.coords = atlas == "UI-HUD-ActionBar-Keyring-Small" and { 0.1, 0.3, 0.2, 0.4 } or { 0, 1, 0, 1 }
    end
    function r:GetTexCoord()
        return unpack(self.coords)
    end
    function r:SetTexCoord(...)
        self.coords = { ... }
    end
    function r:GetRotation()
        return self.rotation
    end
    function r:SetRotation(rotation)
        self.rotation = rotation
    end
    function r:IsShown()
        return self.shown
    end
    function r:GetParent()
        return self.parent
    end
    function r:SetParent(parent)
        self.parent = parent
    end
    function r:IsVisible()
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    function r:SetShown(shown)
        self.shown = shown
    end
    function r:Show()
        self.shown = true
    end
    function r:Hide()
        self.shown = false
    end
    function r:GetNumMaskTextures()
        return #self.masks
    end
    function r:GetMaskTexture(i)
        return self.masks[i]
    end
    function r:AddMaskTexture(mask)
        self.masks[#self.masks + 1] = mask
    end
    function r:RemoveMaskTexture(mask)
        for i = #self.masks, 1, -1 do
            if self.masks[i] == mask then
                table.remove(self.masks, i)
            end
        end
    end
    function r:CreateMaskTexture()
        maskCount = maskCount + 1
        return region()
    end
    return r
end
hooksecurefunc = function(object, key, callback)
    hookCount = hookCount + 1
    local original = object[key]
    object[key] = function(...)
        original(...)
        callback(...)
    end
end
local module = { events = {} }
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent(event)
        module.events[event] = true
    end
    function frame:UnregisterAllEvents()
        module.events = {}
    end
    function frame:SetScript(_, callback)
        self.callback = callback
    end
    return frame
end
function module:SetEnabledState(enabled)
    self.enabled = enabled
end
function module:IsEnabled()
    return self.enabled
end
function module:RegisterEvent(event, method)
    self.events[event] = method
end
function module:UnregisterAllEvents()
    self.events = {}
end
function module:Enable()
    self.enabled = true
    self:OnEnable()
end
function module:Disable()
    self.enabled = false
    self:OnDisable()
end
local addon = { enabled = true }
function addon:IsEnabled()
    return self.enabled
end
function addon:NewModule()
    return module
end
local app = { addon = addon, db = { profile = { bags = { retailStyle = false, spacing = 4 } } } }
assert(loadfile("SeamlessActionBars/src/bagstyle.lua"))("SeamlessActionBars", app)
app.RefreshBagStyle()
assert(
    hookCount == 0 and maskCount == 0 and next(module.events) == nil,
    "default off installs nothing, even with no native frames"
)

local list = {}
local function button(id)
    local b = region()
    b.id, b.icon, b.SquareMask = id, region(), region()
    b.icon:SetTexture("native-icon-" .. id)
    b.icon:AddMaskTexture(b.SquareMask)
    b.normal, b.pushed, b.highlight, b.SlotHighlightTexture = region(), region(), region(), region()
    function b:GetID()
        return self.id
    end
    function b:GetNormalTexture()
        return self.normal
    end
    function b:GetPushedTexture()
        return self.pushed
    end
    function b:GetHighlightTexture()
        return self.highlight
    end
    function b:UpdateTextures()
        if self.bagAtlas then
            self.icon:SetAtlas(self.bagAtlas)
        end
        self.normal:SetAtlas("square")
        self.pushed:SetAtlas("square")
        self.highlight:SetAtlas("square-highlight")
        self.SlotHighlightTexture:SetAtlas("square-highlight")
    end
    b:UpdateTextures()
    list[#list + 1] = b
    return b
end
MainMenuBarBackpackButton = button(0)
for i = 0, 3 do
    _G["CharacterBag" .. i .. "Slot"] = button(i + 1)
end
CharacterReagentBag0Slot, KeyRingButton = button(5), button(6)
KeyRingButton.bagAtlas = "UI-HUD-ActionBar-Keyring-Small"
KeyRingButton.icon:SetAtlas("UI-HUD-ActionBar-Keyring-Small")
KeyRingButton.icon:SetTexCoord(0.1, 0.3, 0.2, 0.4)
BagsBar, BagBarExpandToggle = region(), region()
local cluster = region()
cluster:SetParent(BagsBar)
BagBarExpandToggle:SetParent(cluster)
BagsBar.hideExpandToggle, BagsBar.horizontal, BagsBar.reverse = true, true, true
BagsBar.bagBarExpandToggleInitialWidth, BagsBar.bagBarExpandToggleInitialHeight = 0, 0
BagsBar.BorderArt = region()
function BagsBar:IsHorizontal()
    return self.horizontal
end
function BagsBar:IsDirectionLeft()
    return self.horizontal and self.reverse
end
function BagsBar:IsDirectionUp()
    return not self.horizontal and self.reverse
end
local divider = region()
local dividerPool = {
    EnumerateActive = function()
        return pairs({ [divider] = true })
    end,
}
BagsBar.HorizontalDividersPool, BagsBar.VerticalDividersPool = dividerPool, dividerPool
function BagsBar:UpdateDividers()
    divider:Show()
end
function BagsBar:Layout()
    self:UpdateDividers()
    self:SetSize(self.horizontal and 315 or 45, self.horizontal and 45 or 315)
    if not self.hideExpandToggle then
        BagBarExpandToggle:SetSize(
            self.horizontal and self.bagBarExpandToggleInitialWidth or self.bagBarExpandToggleInitialHeight,
            self.horizontal and self.bagBarExpandToggleInitialHeight or self.bagBarExpandToggleInitialWidth
        )
    end
    for _, b in ipairs(list) do
        b:SetSize(45, 45)
        b:ClearAllPoints()
        b:SetPoint("CENTER", self, "CENTER", 0, 0)
    end
end
-- The client caches this callback at OnLoad, before the addon's table-method hook.
local expandLayout = BagsBar.Layout
function BagBarExpandToggle:UpdateOrientation() end
BagBarExpandToggle:SetSize(10, 16)
BagBarExpandToggle:Hide()
MainMenuBarBagManager = {
    expanded = false,
    IsBarUserExpanded = function(self)
        return self.expanded
    end,
    SetExpandBar = function(self, expanded)
        if self.expanded ~= expanded then
            self.expanded = expanded
            self:OnExpandBarChanged()
        end
    end,
    ToggleExpandBar = function()
        SetCVar("expandBagBar", not GetCVarBool("expandBagBar"))
    end,
    EnumerateBagButtons = function()
        return ipairs(list)
    end,
    OnExpandBarChanged = function(self)
        for _, b in ipairs(list) do
            if b ~= MainMenuBarBackpackButton and b ~= CharacterReagentBag0Slot and b ~= KeyRingButton then
                b:SetShown(self.expanded)
            end
        end
        expandLayout(BagsBar)
    end,
}
local expandedCVar = false
GetCVarBool = function()
    return expandedCVar
end
SetCVar = function(_, value)
    expandedCVar = value
    MainMenuBarBagManager:SetExpandBar(value)
end
app.db.profile.bags.expanded = false
app.db.profile.bags.retailStyle = true
app.RefreshBagStyle()
assert(hookCount == 11 and maskCount == 6)
BagsBar:UpdateDividers()
assert(not divider:IsShown(), "direct native divider refresh stays hidden with retail style")
expandLayout(BagsBar)
assert(not divider:IsShown(), "cached login layout cannot restore native dividers")
app.RefreshBagStyle()
assert(not CharacterBag0Slot:IsShown(), "reload reapplies collapse even when the CVar and manager already match")
MainMenuBarBagManager:SetExpandBar(true)
assert(app.db.profile.bags.expanded == false, "native initialization does not overwrite the saved preference")
app.RefreshBagStyle()
assert(not CharacterBag0Slot:IsShown())
assert(MainMenuBarBackpackButton:GetWidth() == 48 and MainMenuBarBackpackButton.icon:GetAlpha() == 0)
assert(
    CharacterBag0Slot:GetWidth() == 30 and KeyRingButton:GetWidth() == 30 and CharacterReagentBag0Slot:GetWidth() == 30
)
assert(CharacterBag1Slot.normal:GetAtlas() == "bag-border-empty")
assert(CharacterReagentBag0Slot.normal:GetAtlas() == "bag-reagent-border")
assert(KeyRingButton.icon:GetTexture() == "Interface\\Icons\\ui-hud-actionbar-keyring")
assert(
    CharacterBag0Slot.icon:GetNumMaskTextures() == 1
        and CharacterBag0Slot.icon:GetMaskTexture(1) ~= CharacterBag0Slot.SquareMask
)
assert(BagBarExpandToggle:IsShown() and not BagsBar.hideExpandToggle and BagsBar.BorderArt:GetAlpha() == 0)
cluster:Hide()
assert(BagBarExpandToggle:IsVisible(), "collapse must not hide the expand button with its original parent")
cluster:Show()
for _, horizontal in ipairs({ true, false }) do
    for _, reverse in ipairs({ true, false }) do
        BagsBar.horizontal, BagsBar.reverse = horizontal, reverse
        BagsBar:Layout()
        for _, spacing in ipairs({ 0, 8, 20 }) do
            app.db.profile.bags.spacing = spacing
            app.RefreshBagStyle()
            local _, _, _, x, y = KeyRingButton:GetPoint(1)
            local offset = reverse and -spacing or spacing
            assert(x == (horizontal and offset or 0) and y == (horizontal and 0 or -offset))
            assert((horizontal and BagsBar:GetWidth() or BagsBar:GetHeight()) == 238 + 6 * spacing)
        end
        app.db.profile.bags.spacing = 4
        app.RefreshBagStyle()
        assert((horizontal and BagsBar:GetHeight() or BagsBar:GetWidth()) == 48)
        assert(KeyRingButton:GetWidth() == 30 and KeyRingButton:GetHeight() == 30)
        local point, anchor = KeyRingButton:GetPoint(1)
        assert(point == (horizontal and (reverse and "RIGHT" or "LEFT") or (reverse and "BOTTOM" or "TOP")))
        assert(anchor == CharacterReagentBag0Slot, "reagent and keyring both remain in the native order")
        local expandedWidth, expandedHeight = BagsBar:GetWidth(), BagsBar:GetHeight()
        local backpackPoint, backpackAnchor, backpackRelativePoint = MainMenuBarBackpackButton:GetPoint(1)
        MainMenuBarBagManager.expanded = false
        MainMenuBarBagManager:OnExpandBarChanged()
        assert(not CharacterBag0Slot:IsShown(), "collapse hides ordinary bags")
        assert(
            BagsBar:GetWidth() == expandedWidth and BagsBar:GetHeight() == expandedHeight,
            "collapse preserves the bar footprint so center and edge anchors keep the backpack fixed"
        )
        local collapsedPoint, collapsedAnchor, collapsedRelativePoint = MainMenuBarBackpackButton:GetPoint(1)
        assert(
            collapsedPoint == backpackPoint
                and collapsedAnchor == backpackAnchor
                and collapsedRelativePoint == backpackRelativePoint
        )
        assert(
            BagBarExpandToggle:IsVisible() and BagBarExpandToggle:GetWidth() > 0 and BagBarExpandToggle:GetHeight() > 0
        )
        assert(
            (horizontal and BagsBar:GetHeight() or BagsBar:GetWidth()) == 48,
            "cached native callback is followed by retail layout"
        )
        MainMenuBarBagManager.expanded = true
        MainMenuBarBagManager:OnExpandBarChanged()
        assert(BagsBar:GetWidth() == expandedWidth and BagsBar:GetHeight() == expandedHeight)
        assert(
            CharacterBag0Slot:IsShown() and CharacterBag0Slot:GetWidth() == 30,
            "re-expand works immediately without combat exit"
        )
        combat = true
        MainMenuBarBagManager.expanded = false
        MainMenuBarBagManager:OnExpandBarChanged()
        assert(
            KeyRingButton:GetWidth() == 30 and KeyRingButton:GetHeight() == 30,
            "combat collapse keeps keyring circular"
        )
        assert(BagsBar:GetWidth() == expandedWidth and BagsBar:GetHeight() == expandedHeight)
        KeyRingButton:UpdateTextures()
        assert(KeyRingButton.normal:GetAtlas() == "bag-border", "combat inventory refresh keeps the retail skin")
        MainMenuBarBagManager.expanded = true
        MainMenuBarBagManager:OnExpandBarChanged()
        assert(CharacterBag0Slot:IsShown() and KeyRingButton:GetWidth() == 30)
        combat = false
    end
end
CharacterBag0Slot:UpdateTextures()
assert(CharacterBag0Slot.normal:GetAtlas() == "bag-border", "native inventory redraw keeps the skin")
local installedHooks = hookCount
SetCVar("expandBagBar", true)
MainMenuBarBagManager:ToggleExpandBar()
assert(app.db.profile.bags.expanded == false and not CharacterBag0Slot:IsShown())
-- Temporary auto-expansion goes through the manager's change notification, not SetExpandBar.
MainMenuBarBagManager.expanded = true
MainMenuBarBagManager:OnExpandBarChanged()
assert(app.db.profile.bags.expanded == false, "auto expansion must not change the user's preference")
local collapsedProfile = app.db.profile
app.db.profile = { bags = { retailStyle = true, spacing = 0, expanded = true } }
app.RefreshBagStyle()
assert(expandedCVar and CharacterBag0Slot:IsShown(), "new profile restores expanded state")
app.db.profile = collapsedProfile
app.RefreshBagStyle()
assert(not expandedCVar and not CharacterBag0Slot:IsShown(), "switching back restores collapsed state")
SetCVar("expandBagBar", true)
combat = true
app.db.profile = { bags = { retailStyle = false, spacing = 4 } }
app.RefreshBagStyle()
assert(CharacterBag0Slot:GetWidth() == 30 and module.events.PLAYER_REGEN_ENABLED, "combat defers restoration")
combat = false
module:Refresh()
assert(next(module.events) == nil and BagsBar.hideExpandToggle and not BagBarExpandToggle:IsShown())
assert(BagsBar.bagBarExpandToggleInitialWidth == 0 and BagsBar.bagBarExpandToggleInitialHeight == 0)
assert(BagsBar.BorderArt:GetAlpha() == 1 and MainMenuBarBackpackButton.icon:GetAlpha() == 1)
for _, b in ipairs(list) do
    assert(b:GetWidth() == 45 and b.normal:GetAtlas() == "square")
    assert(b.icon:GetNumMaskTextures() == 1 and b.icon:GetMaskTexture(1) == b.SquareMask)
end
assert(
    KeyRingButton.icon:GetAtlas() == "UI-HUD-ActionBar-Keyring-Small",
    "restore the keyring atlas, not just its sheet"
)
assert(KeyRingButton.icon.coords[1] == 0.1 and KeyRingButton.icon.coords[4] == 0.4, "restore keyring atlas coordinates")
assert(BagBarExpandToggle:GetParent() == cluster, "restore the original arrow parent")
CharacterBag0Slot:UpdateTextures()
assert(CharacterBag0Slot.normal:GetAtlas() == "square", "disabled hooks are inert")
BagsBar:UpdateDividers()
assert(divider:IsShown(), "disabled style leaves native dividers visible")
app.db.profile.bags.retailStyle = true
app.db.profile.bags.expanded = true
app.RefreshBagStyle()
assert(hookCount == installedHooks and maskCount == 6, "re-enable reuses hooks and masks")
addon.enabled = false
app.RefreshBagStyle()
assert(MainMenuBarBackpackButton.icon:GetAlpha() == 1 and next(module.events) == nil, "addon disable restores")
print(
    "Bag style OK (default-off inactivity, all seven buttons, native redraw, four directions, combat, profile and addon restoration)"
)
