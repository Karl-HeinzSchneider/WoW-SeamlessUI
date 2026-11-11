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
local nativeScales = {}
local nativePoints = {}
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

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsShown(frame)
    local shown = frame:IsShown()
    return not IsSecret(shown) and shown
end

local function CanChangeInCombat(frame)
    local protected = frame:IsProtected()
    return not IsSecret(protected) and not protected
end

local function ReadAnchor(frame)
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if IsSecret(point) or IsSecret(relative) or IsSecret(relativePoint) or IsSecret(x) or IsSecret(y) then
        return nil
    end
    return { point, relative, relativePoint, x, y }
end

local function ApplyPosition(frame, position, relative)
    if not frame then
        return
    end
    if InCombatLockdown() then
        if not app.db.profile.combinedBags.positionInCombat or not CanChangeInCombat(frame) then
            return
        end
    end
    local parentScale, frameScale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
    if IsSecret(parentScale) or IsSecret(frameScale) then
        return
    end
    local nativePoint = nativePoints[frame] or ReadAnchor(frame)
    if not nativePoint then
        return
    end
    nativePoints[frame] = nativePoint
    local scale = parentScale / frameScale
    frame:ClearAllPoints()
    frame:SetPoint(position.point, relative, position.relativePoint, position.x * scale, position.y * scale)
end

local function RestorePositions()
    if InCombatLockdown() then
        return
    end
    for frame, point in pairs(nativePoints) do
        frame:ClearAllPoints()
        if point[1] then
            frame:SetPoint(unpack(point, 1, 5))
        end
        nativePoints[frame] = nil
    end
end

local function SetBagScale(frame, scale)
    local previous = frame:GetScale()
    if IsSecret(previous) then
        return false
    end
    if previous == scale then
        return true
    end
    local point = ReadAnchor(frame)
    if not point then
        return false
    end
    frame:SetScale(scale)
    if point[1] then
        local ratio = previous / scale
        frame:ClearAllPoints()
        frame:SetPoint(point[1], point[2], point[3], point[4] * ratio, point[5] * ratio)
    end
    return true
end

local function GetBagFrames()
    -- Read the allocated frames directly to avoid populating Blizzard's layout caches.
    local usingCombined = ContainerFrameSettingsManager and ContainerFrameSettingsManager:IsUsingCombinedBags()
    local allocated = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames or {}
    local frames = {}
    if usingCombined and IsShown(ContainerFrameCombinedBags) then
        frames[1] = ContainerFrameCombinedBags
    end
    for _, frame in ipairs(allocated) do
        if IsShown(frame) then
            local id = frame:GetBagID()
            if not IsSecret(id) then
                local isInventoryBag = usingCombined and ContainerFrame_IsReagentBag(id)
                    or not usingCombined and id >= Enum.BagIndex.Backpack and id <= NUM_TOTAL_BAG_FRAMES
                if id == Enum.BagIndex.Keyring or isInventoryBag then
                    frames[#frames + 1] = frame
                end
            end
        end
    end
    return frames
end

local function RestoreScales(keep)
    if InCombatLockdown() then
        return
    end
    for frame, scale in pairs(nativeScales) do
        if (not keep or not keep[frame]) and SetBagScale(frame, scale) then
            nativeScales[frame] = nil
        end
    end
end

local function RefreshScales(frames, multiplier)
    local keep = {}
    if multiplier ~= 1 then
        local inCombat = InCombatLockdown()
        for _, frame in ipairs(frames) do
            keep[frame] = true
            if not inCombat or CanChangeInCombat(frame) then
                local base = nativeScales[frame] or frame:GetScale()
                if not IsSecret(base) and SetBagScale(frame, base * multiplier) then
                    nativeScales[frame] = base
                end
            end
        end
    end
    RestoreScales(keep)
end

function module:Refresh(fromNativeLayout)
    if not anchor or not self:IsEnabled() then
        return
    end
    local frames = GetBagFrames()
    -- Blizzard chains all other bags and columns to the first shown container.
    local first = frames[1]
    local position = CurrentPosition()
    local relative = RelativeFrame(position.relativeTo)
    local multiplier = app.db.profile.combinedBags.scale or 1
    if InCombatLockdown() then
        if fromNativeLayout then
            RefreshScales(frames, multiplier)
        end
        if SavedPosition() then
            ApplyPosition(first, position, relative)
        end
        return
    end
    RestorePositions()
    RefreshScales(frames, multiplier)
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, relative, position.relativePoint, position.x, position.y)
    anchor:SetShown(lib:IsInEditMode() and showAnchor)
    if SavedPosition() then
        ApplyPosition(first, position, relative)
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
    -- A drag target at the configured anchor point, independent of bag dimensions.
    anchor:SetSize(288, 108)
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
    end, defaults, L["Bags"])
    lib:AddFrameSettings(anchor, app.core:GetEditModePageSettings(appName, "combinedBags"))
    if not hooked then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            -- Blizzard just placed every shown bag. Leave its layout routine to the client:
            -- calling it from addon code can taint the container manager's shared caches.
            for frame in pairs(nativePoints) do
                if IsShown(frame) then
                    nativePoints[frame] = nil
                end
            end
            for frame in pairs(nativeScales) do
                if IsShown(frame) then
                    nativeScales[frame] = nil
                end
            end
            if not module:IsEnabled() then
                return
            end
            if InCombatLockdown() then
                module:Refresh(true)
                return
            end
            UpdateDefaults()
            module:Refresh()
        end)
        hooked = true
    end
    self:Refresh()
    app.core:RefreshEditModeOptions()
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "TryInitialize")
    self:RegisterEvent("USE_COMBINED_BAGS_CHANGED", function()
        -- Let Blizzard finish switching modes and reopening its containers.
        C_Timer.After(0, function()
            if self:IsEnabled() then
                self:Refresh()
                app.core:RefreshOptions(appName)
            end
        end)
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self:TryInitialize()
        self:Refresh()
    end)
    self:TryInitialize()
    self:Refresh()
end

function module:OnDisable()
    if anchor then
        anchor:Hide()
        if (next(nativePoints) or next(nativeScales)) and InCombatLockdown() then
            -- Ace removes module events on disable; defer native restoration on our own frame.
            anchor:RegisterEvent("PLAYER_REGEN_ENABLED")
            anchor:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if not module:IsEnabled() then
                    RestorePositions()
                    RestoreScales()
                end
            end)
        end
    end
    RestorePositions()
    RestoreScales()
    app.core:RefreshEditModeOptions()
end

function module:OnProfileRefresh()
    if self:IsEnabled() and not InCombatLockdown() then
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
            name = L["Bags"],
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
