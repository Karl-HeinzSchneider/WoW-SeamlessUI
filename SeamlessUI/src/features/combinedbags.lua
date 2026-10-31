---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.CombinedBags : AceModule, AceEvent-3.0
local module = app.addon:NewModule("CombinedBags", "AceEvent-3.0") --[[@as SeamlessUI.CombinedBags]]
app.combinedBags = module

local lib = app.core:GetEditModeLibrary()
local anchor
local hooked = false
local showAnchor = false
-- The client's placement of the first bag (UpdateContainerFrameAnchors in ContainerFrame.lua):
-- BOTTOMRIGHT on UIParent, GetInitialContainerFrameOffsetX() to the left (the right action bars'
-- width plus 10, or 20 with the gamepad UI) and CONTAINER_OFFSET_Y (85) up, in UIParent units.
local defaults = { point = "BOTTOMRIGHT", x = -10, y = 85 }

local function UpdateDefaults()
    local offsetX = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() and 20 or 10
    local rightBars = EditModeUtil and EditModeUtil.GetRightActionBarWidth and EditModeUtil:GetRightActionBarWidth()
    defaults.x = -((tonumber(rightBars) or 0) + offsetX)
    defaults.y = CONTAINER_OFFSET_Y or 85
end

local function SavedPosition()
    local name = lib:GetActiveLayoutName()
    return name and app.db.profile.combinedBags.layouts[name]
end

local function CurrentPosition()
    local position = SavedPosition() or defaults
    return {
        point = position.point,
        relativePoint = position.relativePoint or position.point,
        relativeTo = position.relativeTo or "UIParent",
        x = position.x,
        y = position.y,
    }
end

local function RelativeFrame(name)
    if name == "UIParent" then
        return UIParent
    end
    for _, entry in ipairs(app.blizzardPosition:GetAnchorFrames(anchor)) do
        if entry.value == name then
            return _G[name] or UIParent
        end
    end
    return UIParent
end

local function ApplyPosition(position, relative)
    local frame = ContainerFrameCombinedBags
    if InCombatLockdown() then
        if not app.db.profile.combinedBags.positionInCombat or frame:IsProtected() then
            return
        end
    end
    local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint(position.point, relative, position.relativePoint, position.x * scale, position.y * scale)
end

function module:Refresh()
    if not anchor or not self:IsEnabled() then
        return
    end
    local position = CurrentPosition()
    local relative = RelativeFrame(position.relativeTo)
    if InCombatLockdown() then
        if SavedPosition() then
            ApplyPosition(position, relative)
        end
        return
    end
    local frame = ContainerFrameCombinedBags
    local ratio = frame:GetEffectiveScale() / anchor:GetEffectiveScale()
    local width, height = frame:GetWidth(), frame:GetHeight()
    anchor:SetSize((width > 0 and width or 400) * ratio, (height > 0 and height or 500) * ratio)
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, relative, position.relativePoint, position.x, position.y)
    anchor:SetShown(lib:IsInEditMode() and showAnchor)
    if SavedPosition() then
        -- Keep the native parent, scale, visibility and item buttons. Offsets are in
        -- UIParent units, so convert them to the bag's effective scale.
        ApplyPosition(position, relative)
    end
end

function module:EditModeVisibility(value)
    if value ~= nil then
        showAnchor = value
        EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
        self:Refresh()
    end
    return showAnchor
end

function module:ResetPosition()
    local name = lib:GetActiveLayoutName()
    if name and self:IsEnabled() and not InCombatLockdown() then
        app.db.profile.combinedBags.layouts[name] = nil
        UpdateContainerFrameAnchors()
        self:Refresh()
        lib:RefreshFrameSettings(anchor)
    end
end

function module:GetPositionBinding()
    return {
        get = function(key)
            return CurrentPosition()[key]
        end,
        default = function(key)
            UpdateDefaults()
            local values = { relativePoint = defaults.point, relativeTo = "UIParent" }
            return values[key] or defaults[key]
        end,
        set = function(key, value)
            local name = lib:GetActiveLayoutName()
            if not name or not module:IsEnabled() or InCombatLockdown() then
                return
            end
            local position = CurrentPosition()
            position[key] = value
            app.db.profile.combinedBags.layouts[name] = position
            module:Refresh()
        end,
        anchorFrames = function()
            return app.blizzardPosition:GetAnchorFrames(anchor)
        end,
    }
end

function module:TryInitialize()
    if anchor or not ContainerFrameCombinedBags or not UpdateContainerFrameAnchors or InCombatLockdown() then
        return
    end
    anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetSize(400, 500)
    anchor:SetClampedToScreen(true)
    anchor:Hide()
    UpdateDefaults()
    lib:AddFrame(anchor, function(_, name, point, x, y)
        if module:IsEnabled() and name and not InCombatLockdown() then
            -- A drag always breaks the previous anchor and stores UIParent coordinates.
            app.db.profile.combinedBags.layouts[name] = { point = point, x = x, y = y }
            module:Refresh()
            lib:RefreshFrameSettings(anchor)
        end
    end, defaults, L["Combined bags"])
    lib:AddFrameSettings(anchor, app.core:GetEditModePageSettings(appName, "combinedBags"))
    if not hooked then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            if not module:IsEnabled() then
                return
            end
            if InCombatLockdown() then
                module:Refresh()
                return
            end
            UpdateDefaults()
            module:Refresh()
        end)
        hooked = true
    end
    UpdateContainerFrameAnchors()
    self:Refresh()
    app.core:RefreshEditModeOptions()
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "TryInitialize")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self:TryInitialize()
        if UpdateContainerFrameAnchors then
            UpdateContainerFrameAnchors()
        end
        self:Refresh()
    end)
    self:TryInitialize()
    self:Refresh()
end

function module:OnDisable()
    if anchor then
        anchor:Hide()
        if InCombatLockdown() then
            -- Ace removes module events on disable; defer native restoration on our own frame.
            anchor:RegisterEvent("PLAYER_REGEN_ENABLED")
            anchor:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                UpdateContainerFrameAnchors()
            end)
        end
    end
    if UpdateContainerFrameAnchors and not InCombatLockdown() then
        UpdateContainerFrameAnchors()
    end
    app.core:RefreshEditModeOptions()
end

function module:OnProfileRefresh()
    if self:IsEnabled() and UpdateContainerFrameAnchors and not InCombatLockdown() then
        UpdateContainerFrameAnchors()
        self:Refresh()
    end
end

app.core:RegisterEditModeOptions("SeamlessUI.CombinedBags", {
    section = "frames",
    enabled = function()
        return app.db and app.addon:IsEnabled() and module:IsEnabled() and anchor ~= nil
    end,
    options = {
        {
            key = "combinedBags",
            type = "toggle",
            name = L["Combined bags"],
            get = function()
                return module:EditModeVisibility()
            end,
            set = function(value)
                module:EditModeVisibility(value)
            end,
        },
    },
})

for _, event in ipairs({ "enter", "exit", "layout" }) do
    lib:RegisterCallback(event, function()
        module:OnProfileRefresh()
    end)
end

local function ForEachLayout(callback)
    if app.db then
        for _, profile in pairs(app.db.profiles) do
            if profile.combinedBags and profile.combinedBags.layouts then
                callback(profile.combinedBags.layouts)
            end
        end
    end
end

lib:RegisterCallback("create", function(name, _, sourceName)
    ForEachLayout(function(layouts)
        local source = sourceName and layouts[sourceName]
        if source then
            local copy = {}
            for key, value in pairs(source) do
                copy[key] = value
            end
            layouts[name] = copy
        end
    end)
end)
lib:RegisterCallback("rename", function(oldName, newName)
    ForEachLayout(function(layouts)
        layouts[newName], layouts[oldName] = layouts[oldName], nil
    end)
end)
lib:RegisterCallback("delete", function(name)
    ForEachLayout(function(layouts)
        layouts[name] = nil
    end)
end)
